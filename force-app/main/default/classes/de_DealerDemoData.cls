/**
 * de_DealerDemoData
 * Single source of truth for the Hueline Paints dealer demo (Hueline Service Agent).
 * Holds the product catalogue, dealer/account/credit figures, scheme and service data,
 * and the basket math. Every action class reads from here so the numbers in section 7
 * of the demo board never drift. Totals are always recomputed from the line items,
 * never restated from a constant.
 */
public with sharing class de_DealerDemoData {

    // ---- Dealer & account (data pack 7.1) ----
    public static final String DEALER_NAME     = 'Anil ji';
    public static final String ACCOUNT_NAME    = 'Lakeview Colour & Hardware';
    public static final String DEALER_CODE     = 'HL-PUN-04417';
    public static final String CONTACT_NAME    = 'Anil Verma';
    public static final String TERRITORY       = 'Pune West · Kothrud';
    public static final String TIER            = 'Gold dealer, 11 years';
    public static final String DEPOT           = 'Bhosari';
    public static final String SERVICE_OFFICER = 'Meera Rao';
    public static final Long   CREDIT_LIMIT    = 1200000;
    public static final Long   CREDIT_USED     = 580000;
    public static final Long   CREDIT_AVAIL    = 620000;

    // ---- Product catalogue (data pack 7.2) ----
    // sku => { name, pack, rate }. Rate is the product's catalogue Price (flat per family:
    // Paint ₹100 · Putty ₹7,900 · Emulsion ₹5,700). Conversion factor (bundle size) is not
    // stored here — it lives on Product2.Conversion_Factor__c for the cart-add validation.
    public static Map<String, Map<String, Object>> catalogue() {
        Map<String, Map<String, Object>> c = new Map<String, Map<String, Object>>();
        // Paint — HL GLOSSCOAT Gloss Enamel (₹100)
        c.put('HL000000011', prod('HL GLOSSCOAT ENML BLACK 1 LT', '1 L', 100));
        c.put('HL000000005', prod('HL GLOSSCOAT ENML G BROWN 1 LT', '1 L', 100));
        c.put('HL000000002', prod('HL GLOSSCOAT ENML BROWN 1 LT', '1 L', 100));
        c.put('HL000000010', prod('HL GLOSSCOAT ENML BLACK 500ML', '500 ML', 100));
        c.put('HL000000007', prod('HL GLOSSCOAT ENML SM GREY 1 LT', '1 L', 100));
        c.put('HL000000004', prod('HL GLOSSCOAT ENML G BROWN 500ML', '500 ML', 100));
        c.put('HL000000001', prod('HL GLOSSCOAT ENML BROWN 500ML', '500 ML', 100));
        c.put('HL000000012', prod('HL GLOSSCOAT ENML BLACK 4 LT', '4 L', 100));
        c.put('HL000000006', prod('HL GLOSSCOAT ENML G BROWN 4 LT', '4 L', 100));
        c.put('HL000000009', prod('HL GLOSSCOAT ENML BLACK 200ML', '200 ML', 100));
        c.put('HL000000003', prod('HL GLOSSCOAT ENML BROWN 4 LT', '4 L', 100));
        c.put('HL000000008', prod('HL GLOSSCOAT ENML SM GREY 4 LT', '4 L', 100));
        // Putty — Wall Putty (₹7,900)
        c.put('HL000000031', prod('Smoothset Wall Putty WHITE 40 KG', '40 KG', 7900));
        c.put('HL000000029', prod('Smoothset Wall Putty WHITE 20 KG', '20 KG', 7900));
        c.put('HL000000028', prod('HUELINE WALLPUTTY WHITE 5KG', '5 KG', 7900));
        c.put('HL000000027', prod('HUELINE WALLPUTTY WHITE 1KG-P', '1 KG', 7900));
        c.put('HL000000030', prod('HUELINE WALLPUTTY WHITE 30 KG', '30 KG', 7900));
        c.put('HL000000038', prod('HLEXTWLPUTTY NOTKN 40KG', '40 KG', 7900));
        c.put('HL000000032', prod('HLEXTWLPUTTY WHITEWT 30LT', '30 KG', 7900));
        c.put('HL000000033', prod('HLEXTWLPUTTY S30 30LT', '30 KG', 7900));
        c.put('HL000000035', prod('HLEXTWLPUTTY PUTTYST 1KG', '1 KG', 7900));
        c.put('HL000000034', prod('HLEXTWLPUTTY S40 40LT', '40 KG', 7900));
        c.put('HL000000036', prod('HLEXTWLPUTTY PUTTYST 5LT', '5 KG', 7900));
        c.put('HL000000037', prod('HLEXTWLPUTTY PUTTYST 20LT', '20 KG', 7900));
        // Emulsion — Fieldcoat Emulsion (₹5,700)
        c.put('HL000000017', prod('HL FIELDCOAT EMUL TE 1 1 LT', '1 L', 5700));
        c.put('HL000000019', prod('HL FIELDCOAT EMUL TE 1 10 LT', '10 L', 5700));
        c.put('HL000000020', prod('HL FIELDCOAT EMUL TE 1 20 LT', '20 L', 5700));
        c.put('HL000000018', prod('HL FIELDCOAT EMUL TE 1 4 LT', '4 L', 5700));
        c.put('HL000000021', prod('HLFIELDCOATEMUL HLTE22N 900ML', '900 ML', 5700));
        c.put('HL000000013', prod('HL FIELDCOAT EMUL SUPWHITE 1 LTR', '1 L', 5700));
        c.put('HL000000016', prod('HL FIELDCOAT EMUL SUPWHITE 20 LTR', '20 L', 5700));
        c.put('HL000000022', prod('HLFIELDCOATEMUL HLTE22N 3.6LT', '3.6 L', 5700));
        c.put('HL000000015', prod('HL FIELDCOAT EMUL SUPWHITE 10 LTR', '10 L', 5700));
        c.put('HL000000014', prod('HL FIELDCOAT EMUL SUPWHITE 4 LTR', '4 L', 5700));
        c.put('HL000000023', prod('HL FIELDCOAT EMUL SWHT TN 10LT', '10 L', 5700));
        c.put('HL000000025', prod('HL FIELDCOAT EMUL SWHT KA 10LT', '10 L', 5700));
        c.put('HL000000024', prod('HL FIELDCOAT EMUL SWHT KA 4LT', '4 L', 5700));
        c.put('HL000000026', prod('HL FIELDCOAT EMUL SWHT KA 20LT', '20 L', 5700));
        return c;
    }

    private static Map<String, Object> prod(String name, String pack, Integer rate) {
        return new Map<String, Object>{ 'name' => name, 'pack' => pack, 'rate' => rate };
    }

    // ---- Bundle sizes (data pack 7.2b) : how many units make one orderable bundle ----
    // The bundle size lives on Product2.Conversion_Factor__c (NOT in the catalogue map above),
    // so the demo reads the SAME field the business uses. A product may only be ordered in whole
    // multiples of this number — e.g. a Conversion_Factor__c of 5 means the dealer can order
    // 5, 10, 15 … but not 2 or 7. Queried once per transaction and cached (basketFromLines is
    // called many times, so a per-call SOQL would risk the query governor limit).
    private static Map<String, Integer> bundleCache;
    public static Map<String, Integer> bundleSizes() {
        if (bundleCache != null) { return bundleCache; }
        bundleCache = new Map<String, Integer>();
        try {
            for (Product2 p : [
                SELECT StockKeepingUnit, Conversion_Factor__c
                FROM Product2
                WHERE StockKeepingUnit IN :catalogue().keySet()
            ]) {
                if (String.isNotBlank(p.StockKeepingUnit)
                        && p.Conversion_Factor__c != null
                        && p.Conversion_Factor__c > 0) {
                    bundleCache.put(p.StockKeepingUnit, (Integer) p.Conversion_Factor__c);
                }
            }
        } catch (Exception e) {
            // If Product2 can't be read for any reason, degrade gracefully to "bundle of 1"
            // (every quantity valid) rather than block the whole order journey.
        }
        return bundleCache;
    }

    // Bundle size for a SKU — defaults to 1 (any quantity allowed) when unknown or not set.
    public static Integer bundleOf(String sku) {
        Integer b = bundleSizes().get(sku);
        return (b == null || b <= 0) ? 1 : b;
    }

    // ---- Normalise the dealer's chosen input method to a canonical token ----
    // The input-methods card sends labels like "Upload a photo" / "Send a voice note";
    // downstream code keys off photo | file | voice | manual.
    public static String normaliseMethod(String raw) {
        String s = (raw == null ? '' : raw).toLowerCase();
        if (s.contains('photo') || s.contains('image') || s.contains('picture') || s.contains('camera')) { return 'photo'; }
        if (s.contains('voice') || s.contains('audio') || s.contains('record') || s.contains('speak')) { return 'voice'; }
        if (s.contains('manual') || s.contains('search') || s.contains('catalog')) { return 'manual'; }
        if (s.contains('file') || s.contains('excel') || s.contains('csv') || s.contains('pdf') || s.contains('upload')) { return 'file'; }
        return 'manual';
    }

    // ---- Catalogue as a flat list of cards (for the manual-search capture UI) ----
    public static List<Object> catalogueList() {
        List<Object> out = new List<Object>();
        Map<String, Map<String, Object>> c = catalogue();
        for (String sku : c.keySet()) {
            Map<String, Object> p = c.get(sku);
            Integer rate = (Integer) p.get('rate');
            Integer bundle = bundleOf(sku);
            out.add(new Map<String, Object>{
                'sku'      => sku,
                'name'     => p.get('name'),
                'pack'     => p.get('pack'),
                'rate'     => rate,
                'rateText' => inr(rate),
                'bundle'   => bundle
            });
        }
        return out;
    }

    // ---- Basket line ----
    public static Map<String, Object> line(String sku, Integer qty, String flag) {
        Map<String, Object> p = catalogue().get(sku);
        Integer rate = (Integer) p.get('rate');
        Map<String, Object> l = new Map<String, Object>{
            'sku'   => sku,
            'name'  => p.get('name'),
            'pack'  => p.get('pack'),
            'qty'   => qty,
            'rate'  => rate,
            'value' => rate * qty,
            'flag'  => (flag == null ? '' : flag)
        };
        return l;
    }

    // ---- The base extracted order (data pack 7.3) : 8 products ----
    // Totals are always recomputed from the lines, so they stay correct after a catalogue swap.
    // Row 7 (Wall Putty 20 KG @ qty 5) is what the Monsoon booster raises to 14 to secure GOLD.
    public static Map<String, Object> baseBasket() {
        List<Object> lines = new List<Object>{
            line('HL000000020', 6, ''),            // Fieldcoat Emul TE1 20 LT
            line('HL000000016', 12, ''),           // Fieldcoat Emul Supwhite 20 LTR
            line('HL000000018', 20, ''),           // Fieldcoat Emul TE1 4 LT
            line('HL000000012', 4, ''),            // Glosscoat Gloss Enamel Black 4 LT
            line('HL000000006', 15, 'confirm'),    // row 5 - the deliberate ambiguity
            line('HL000000011', 8, ''),            // Glosscoat Gloss Enamel Black 1 LT
            line('HL000000029', 5, ''),            // Wall Putty 20 KG - booster raises to 14
            line('HL000000028', 3, '')             // Wall Putty 5 KG
        };
        return basketFromLines(lines);
    }

    // ---- An empty basket wrapper (manual entry / analysis builds onto this) ----
    public static Map<String, Object> emptyBasket() {
        return basketFromLines(new List<Object>());
    }

    // ---- Build a basket wrapper with recomputed totals + numbered rows ----
    public static Map<String, Object> basketFromLines(List<Object> lines) {
        Long value = 0;
        Long units = 0;
        Integer n = 0;
        Integer flaggedRow = 0;
        Integer bundleIssues = 0; // lines whose qty is not a whole multiple of their bundle size
        for (Object o : lines) {
            Map<String, Object> l = (Map<String, Object>) o;
            n++;
            l.put('n', n);
            value += asLong(l.get('value'));
            units += asLong(l.get('qty'));
            if (String.valueOf(l.get('flag')) == 'confirm') {
                flaggedRow = n;
            }
            // Bundle (Conversion_Factor__c) validation: a product may only be ordered in whole
            // multiples of its bundle size. Annotate every line so the card can flag bad rows,
            // step +/- in bundle increments, and block "Confirm & Continue" until all are valid.
            Integer qv = asLong(l.get('qty')).intValue();
            Integer bundle = bundleOf(String.valueOf(l.get('sku')));
            Boolean bundleValid = (bundle <= 1) || (Math.mod(qv, bundle) == 0);
            l.put('bundle', bundle);
            l.put('bundleValid', bundleValid);
            l.put('bundleText', bundle > 1 ? ('Sold in bundles of ' + bundle) : '');
            if (!bundleValid) { bundleIssues++; }
        }
        return new Map<String, Object>{
            'lines'        => lines,
            'products'     => lines.size(),
            'units'        => units,
            'value'        => value,
            'valueText'    => inr(value),
            'flaggedRow'   => flaggedRow,
            'bundleOk'     => (bundleIssues == 0),
            'bundleIssues' => bundleIssues
        };
    }

    // ---- Merge items (sku, qty) into an existing basket; never duplicate a line ----
    public static Map<String, Object> mergeItems(Map<String, Object> basket, List<Object> items) {
        List<Object> lines = (List<Object>) basket.get('lines');
        Map<String, Map<String, Object>> bySku = new Map<String, Map<String, Object>>();
        for (Object o : lines) {
            Map<String, Object> l = (Map<String, Object>) o;
            bySku.put(String.valueOf(l.get('sku')), l);
        }
        for (Object io : items) {
            if (!(io instanceof Map<String, Object>)) { continue; }
            Map<String, Object> item = (Map<String, Object>) io;
            // Tolerate key-casing variants the planner emits: sku/SKU/Sku, name/product,
            // qty/quantity/count. The planner does not always echo our exact field names.
            Object skuRaw = pick(item, new Set<String>{ 'sku' });
            String sku = skuRaw == null ? null : String.valueOf(skuRaw);
            if (String.isBlank(sku) || !catalogue().containsKey(sku)) {
                // not a known catalogue SKU — try resolving by product name instead
                Object nameRaw = pick(item, new Set<String>{ 'name', 'product', 'productname' });
                if (nameRaw != null) { sku = resolveSku(String.valueOf(nameRaw)); }
            }
            if (String.isBlank(sku) || !catalogue().containsKey(sku)) {
                continue; // unknown product — skip rather than corrupt the basket
            }
            Object qtyRaw = pick(item, new Set<String>{ 'qty', 'quantity', 'count', 'units' });
            Integer addQty = qtyRaw == null ? 1 : asLong(qtyRaw).intValue();
            if (addQty <= 0) { addQty = 1; }
            if (bySku.containsKey(sku)) {
                Map<String, Object> l = bySku.get(sku);
                Integer newQty = Integer.valueOf(l.get('qty')) + addQty;
                Integer rate = Integer.valueOf(l.get('rate'));
                l.put('qty', newQty);
                l.put('value', rate * newQty);
            } else {
                Map<String, Object> nl = line(sku, addQty, '');
                lines.add(nl);
                bySku.put(sku, nl);
            }
        }
        return basketFromLines(lines);
    }

    // ---- Resolve a product name (full or partial, case-insensitive) to a catalogue SKU ----
    public static String resolveSku(String name) {
        if (String.isBlank(name)) { return null; }
        String needle = name.toLowerCase();
        // exact-ish name match first
        for (String sku : catalogue().keySet()) {
            String prodName = String.valueOf(catalogue().get(sku).get('name')).toLowerCase();
            if (prodName == needle) { return sku; }
        }
        // then contains either direction
        for (String sku : catalogue().keySet()) {
            String prodName = String.valueOf(catalogue().get(sku).get('name')).toLowerCase();
            if (prodName.contains(needle) || needle.contains(prodName)) { return sku; }
        }
        return null;
    }

    // ---- Parse an incoming basket JSON string back to a wrapper (recomputing totals) ----
    public static Map<String, Object> parseBasket(String basketJSON) {
        if (String.isBlank(basketJSON)) {
            return baseBasket();
        }
        Object parsed = JSON.deserializeUntyped(basketJSON);
        // Tolerate a bare array being passed in (e.g. an items array mis-sent as the
        // basket): it is not a basket, so fall back to the base order rather than crash.
        if (!(parsed instanceof Map<String, Object>)) {
            return baseBasket();
        }
        Map<String, Object> raw = (Map<String, Object>) parsed;
        List<Object> lines = (raw.get('lines') instanceof List<Object>) ? (List<Object>) raw.get('lines') : null;
        if (lines == null || lines.isEmpty()) {
            return baseBasket();
        }
        return basketFromLines(lines);
    }

    // ---- Indian number formatting: 290350 -> "Rs 2,90,350" (uses the rupee symbol) ----
    public static String inr(Long amount) {
        if (amount == null) { amount = 0; }
        Boolean neg = amount < 0;
        String digits = String.valueOf(Math.abs(amount));
        String out;
        if (digits.length() <= 3) {
            out = digits;
        } else {
            String last3 = digits.substring(digits.length() - 3);
            String rest = digits.substring(0, digits.length() - 3);
            String grouped = '';
            while (rest.length() > 2) {
                grouped = ',' + rest.substring(rest.length() - 2) + grouped;
                rest = rest.substring(0, rest.length() - 2);
            }
            grouped = rest + grouped;
            out = grouped + ',' + last3;
        }
        return '₹' + (neg ? '-' : '') + out;
    }

    // Read a value from a map by any of several candidate keys, matched case-insensitively.
    // Lets us tolerate planner-emitted variants (SKU/sku, quantity/qty) without crashing.
    private static Object pick(Map<String, Object> m, Set<String> keys) {
        if (m == null) { return null; }
        for (String k : m.keySet()) {
            if (k != null && keys.contains(k.toLowerCase())) {
                return m.get(k);
            }
        }
        return null;
    }

    public static Long asLong(Object o) {
        if (o == null) { return 0; }
        if (o instanceof Integer) { return (Long)(Integer) o; }
        if (o instanceof Long) { return (Long) o; }
        if (o instanceof Decimal) { return ((Decimal) o).longValue(); }
        return Long.valueOf(String.valueOf(o));
    }
}