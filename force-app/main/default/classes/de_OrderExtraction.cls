/**
 * de_OrderExtraction — the real-analysis internals used by de_OrderAnalysis.
 *
 *   extract(contentDocumentId, orderText) : run the order-extraction prompt template
 *                                           over an uploaded image/pdf (by document
 *                                           reference) and/or extracted order text.
 *   transcribe(contentDocumentId)         : run speech-to-text over an audio file.
 *   xlsxToText(versionData)               : flatten an .xlsx workbook to plain text.
 *
 * Each method is fully guarded: any failure (feature off, template missing, bad file)
 * returns blank/empty so de_AnalyzeOrderAction falls back to the scripted demo order.
 * This keeps a live demo from ever dead-ending while still attempting real analysis.
 */
public with sharing class de_OrderExtraction {

    private static final String PROMPT_TEMPLATE_NAME = 'de_Order_Extraction';

    // Diagnostic: the last swallowed failure reason, surfaced by de_AnalyzeOrderAction so a
    // permission/feature gap for the running (agent) user is visible instead of silent-empty.
    public static String lastError = '';

    // ---- Prompt template over an image/pdf document and/or extracted order text ----
    public static String extract(Id contentDocumentId, String orderText) {
        try {
            ConnectApi.EinsteinPromptTemplateGenerationsInput input =
                new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            input.isPreview = false;
            input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            input.additionalConfig.applicationName = 'PromptTemplateGenerationsInvocable';

            Map<String, ConnectApi.WrappedValue> params = new Map<String, ConnectApi.WrappedValue>();

            // optional order text (xlsx/csv already flattened upstream)
            if (String.isNotBlank(orderText)) {
                ConnectApi.WrappedValue textVal = new ConnectApi.WrappedValue();
                textVal.value = orderText;
                params.put('Input:orderText', textVal);
            }

            // optional file reference — SOBJECT://ContentDocument inputs take Map{'id'=>docId},
            // NOT a bare Id string (this was the hard-won gotcha from the reference work).
            if (contentDocumentId != null) {
                ConnectApi.WrappedValue fileVal = new ConnectApi.WrappedValue();
                fileVal.value = new Map<String, Object>{ 'id' => contentDocumentId };
                params.put('Input:file', fileVal);
            }

            input.inputParams = params;

            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation out =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(PROMPT_TEMPLATE_NAME, input);

            if (out != null && out.generations != null && !out.generations.isEmpty()) {
                return out.generations[0].text;
            }
        } catch (Exception e) {
            lastError = 'extract: ' + e.getTypeName() + ': ' + e.getMessage();
            System.debug('de_OrderExtraction.extract failed: ' + e.getMessage());
        }
        return '';
    }

    // ---- Speech-to-text over an audio ContentDocument ----
    // Wired to the de_Order_SpeechToText flow (platform speechToText core action) once
    // the reference flow is in place; returns blank on any failure so the caller falls back.
    public static String transcribe(Id contentDocumentId) {
        try {
            if (contentDocumentId == null) {
                return '';
            }
            Map<String, Object> inputs = new Map<String, Object>{ 'contentDocumentId' => contentDocumentId };
            Flow.Interview flow = Flow.Interview.createInterview('de_Order_SpeechToText', inputs);
            flow.start();
            Object transcript = flow.getVariableValue('transcript');
            return transcript == null ? '' : String.valueOf(transcript);
        } catch (Exception e) {
            System.debug('de_OrderExtraction.transcribe failed: ' + e.getMessage());
        }
        return '';
    }

    // ---- Flatten an .xlsx workbook to plain text (pure Apex, no callout) ----
    // Reads shared strings + every worksheet from the zipped OOXML package. Dates
    // surface as their numeric serial and formatting is dropped — fine for extracting
    // product names and quantities.
    public static String xlsxToText(Blob xlsx) {
        if (xlsx == null) {
            return '';
        }
        try {
            Compression.ZipReader reader = new Compression.ZipReader(xlsx);
            Blob sharedBlob = null;
            Map<String, Blob> sheetBlobs = new Map<String, Blob>();
            for (Compression.ZipEntry entry : reader.getEntries()) {
                String name = entry.getName();
                if (name == 'xl/sharedStrings.xml') {
                    sharedBlob = entry.getContent();
                } else if (name.startsWith('xl/worksheets/') && name.endsWith('.xml')) {
                    sheetBlobs.put(name, entry.getContent());
                }
            }

            List<String> shared = parseSharedStrings(sharedBlob);
            List<String> sheetNames = new List<String>(sheetBlobs.keySet());
            sheetNames.sort();

            List<String> parts = new List<String>();
            for (String sn : sheetNames) {
                String txt = parseSheet(sheetBlobs.get(sn), shared);
                if (String.isNotBlank(txt)) {
                    parts.add(txt);
                }
            }
            return String.join(parts, '\n');
        } catch (Exception e) {
            System.debug('de_OrderExtraction.xlsxToText failed: ' + e.getMessage());
        }
        return '';
    }

    /** Parses xl/sharedStrings.xml into an ordered list of strings (index = string id). */
    private static List<String> parseSharedStrings(Blob xml) {
        List<String> strings = new List<String>();
        if (xml == null) {
            return strings;
        }
        Dom.Document doc = new Dom.Document();
        doc.load(xml.toString());
        for (Dom.XmlNode si : doc.getRootElement().getChildElements()) {
            if (si.getName() == 'si') {
                strings.add(gatherText(si));
            }
        }
        return strings;
    }

    /** Renders one worksheet's rows as tab-delimited lines. */
    private static String parseSheet(Blob xml, List<String> shared) {
        if (xml == null) {
            return '';
        }
        Dom.Document doc = new Dom.Document();
        doc.load(xml.toString());
        Dom.XmlNode sheetData = getChild(doc.getRootElement(), 'sheetData');
        if (sheetData == null) {
            return '';
        }
        List<String> lines = new List<String>();
        for (Dom.XmlNode row : sheetData.getChildElements()) {
            if (row.getName() != 'row') {
                continue;
            }
            List<String> cells = new List<String>();
            for (Dom.XmlNode c : row.getChildElements()) {
                if (c.getName() == 'c') {
                    cells.add(cellValue(c, shared));
                }
            }
            lines.add(String.join(cells, '\t'));
        }
        return String.join(lines, '\n');
    }

    /** Resolves a single cell's display value (shared string, inline string, or literal). */
    private static String cellValue(Dom.XmlNode c, List<String> shared) {
        String t = c.getAttributeValue('t', null);
        if (t == 'inlineStr') {
            Dom.XmlNode isNode = getChild(c, 'is');
            return isNode == null ? '' : gatherText(isNode);
        }
        Dom.XmlNode v = getChild(c, 'v');
        if (v == null) {
            return '';
        }
        String raw = v.getText();
        if (t == 's') {
            try {
                Integer idx = Integer.valueOf(raw);
                return (idx >= 0 && idx < shared.size()) ? shared[idx] : '';
            } catch (Exception e) {
                return '';
            }
        }
        return raw;
    }

    /** Concatenates every descendant <t> text node (handles rich-text runs). */
    private static String gatherText(Dom.XmlNode node) {
        String result = '';
        for (Dom.XmlNode child : node.getChildElements()) {
            if (child.getName() == 't') {
                String txt = child.getText();
                if (txt != null) {
                    result += txt;
                }
            } else {
                result += gatherText(child);
            }
        }
        return result;
    }

    /** First direct child element with the given (namespace-agnostic) local name, or null. */
    private static Dom.XmlNode getChild(Dom.XmlNode parent, String localName) {
        for (Dom.XmlNode ch : parent.getChildElements()) {
            if (ch.getName() == localName) {
                return ch;
            }
        }
        return null;
    }
}