import { LightningElement, api, track } from 'lwc';
import { revealCard } from 'c/de_cardReveal';
import saveManual from '@salesforce/apex/de_OrderCaptureController.saveManual';
import saveVoiceText from '@salesforce/apex/de_OrderCaptureController.saveVoiceText';
import saveFileChunk from '@salesforce/apex/de_OrderCaptureController.saveFileChunk';
import setBasketLineQty from '@salesforce/apex/de_OrderCaptureController.setBasketLineQty';

// de_CaptureData__c is a LongTextArea (131,072 chars). A large file no longer has to fit one
// field: it is split into B64_CHUNK-sized base64 slices, each saved as its own chunk row (sharing
// one upload id) and reassembled server-side. B64_CHUNK stays safely under the field cap. Photos
// are still downscaled to ~one chunk (MAX_B64_CHARS) so OCR stays fast; non-image files (audio,
// PDF) may span many chunks up to MAX_TOTAL_B64 (bounded by Apex heap on reassembly).
const MAX_B64_CHARS = 125000;
const B64_CHUNK = 120000;        // one slice -> one chunk row (< 131,072 field cap)
const MAX_TOTAL_B64 = 2400000;   // ~1.8 MB binary across all chunks

export default class De_orderTable extends LightningElement {
    _value;
    _revealed = false;

    // ---- shared ----
    @track mode = 'table';
    @track errorMessage = '';

    // ---- capture state ----
    @track inputMethod = 'manual';
    @track targetRecordId = '';
    @track childRecordId = ''; // guest-owned child that lightning-file-upload uploads a real file to
    @track catalogue = [];
    @track captureStatus = 'idle'; // idle | recording | saving | analyzing
    @track searchTerm = '';
    @track manualItems = [];
    isRecording = false;
    _preparingUpload = false;

    // ---- live caption (Web Speech API, display-only; the recorded audio is the source of truth) ----
    @track liveFinal = '';     // finalized phrases
    @track liveInterim = '';   // in-progress phrase
    speechRecognition;
    speechSupported = false;

    // ---- table state ----
    @track lines = [];
    @track source = ''; // 'file' = really extracted, 'none' = nothing found (diagnostic)
    @track notFound = false;
    @track emptyMessage = '';
    @track title = 'Your Order';
    @track flaggedRow = 0;
    @track flagQuestion = '';
    @track flagResolved = false;
    @track nextActions = []; // action-supplied "continue the journey" buttons shown under the table
    // ---- bundle (Conversion_Factor__c) validation ----
    @track bundleOk = true;      // false while any line's qty is not a whole multiple of its bundle
    @track bundleMessage = '';   // "N items aren't in valid bundle sizes…" notice from the action
    rowsPerPage = 4;
    @track page = 1;

    @api
    get value() {
        return this._value;
    }
    set value(v) {
        this._value = v;
        this.parseValue();
    }

    connectedCallback() {
        this.parseValue();
    }

    renderedCallback() {
        if (this._revealed || !this._value) {
            return;
        }
        this._revealed = true;
        revealCard(this.template);
    }

    parseValue() {
        const v = this._value;
        if (!v) {
            return;
        }
        const raw = v.dataJSON ? v.dataJSON : v;
        try {
            const data = typeof raw === 'string' ? JSON.parse(raw) : raw;
            if (data && data.mode === 'capture') {
                this.applyCapture(data);
            } else {
                this.applyTable(data);
            }
            this.errorMessage = '';
        } catch (e) {
            this.errorMessage = 'Could not read the order.';
        }
    }

    applyCapture(data) {
        this.mode = 'capture';
        this.inputMethod = data.inputMethod || 'manual';
        this.targetRecordId = data.targetRecordId || '';
        this.childRecordId = '';
        this.catalogue = (data.catalogue || []).map((c) => ({ ...c }));
        this.title = data.title || 'Give me your order';
        this.captureStatus = 'idle';
        this.manualItems = [];
        this.searchTerm = '';
        this.liveFinal = '';
        this.liveInterim = '';
        this.selectedFileName = '';
    }

    // Surface the real server exception so access/permission gaps are visible in-card.
    srvMsg(e) {
        if (e && e.body && e.body.message) {
            return e.body.message;
        }
        if (e && e.message) {
            return e.message;
        }
        return 'unknown error';
    }

    applyTable(data) {
        this.mode = 'table';
        this.source = data.source || '';
        this.notFound = data.notFound === true;
        this.emptyMessage = data.message || '';
        this.title = data.title || 'Your order';
        this.rowsPerPage = data.rowsPerPage || 4;
        this.flaggedRow = data.flaggedRow || 0;
        this.flagQuestion = data.flagQuestion || '';
        this.bundleMessage = data.bundleMessage || '';
        this.lines = (data.lines || []).map((l) => {
            const bundle = Number(l.bundle) || 1;
            return {
                n: l.n,
                sku: l.sku,
                name: l.name,
                pack: l.pack,
                qty: l.qty,
                rate: l.rate,
                value: l.value,
                bundle,
                bundleValid: l.bundleValid !== false,
                flagged: String(l.flag) === 'confirm'
            };
        });
        this.recomputeBundle();
        // Optional "next step" buttons the action supplies to keep the dealer tapping, not typing.
        // 'block' buttons (e.g. Confirm & Continue) stay disabled until every bundle is valid.
        this.nextActions = (data.actions || []).map((a, i) => ({
            key: 'na' + i,
            label: a.label,
            message: a.message || a.label,
            block: a.block === true,
            variant: a.variant
        }));
    }

    // Recompute overall bundle validity from the current lines (after an edit or on load).
    recomputeBundle() {
        this.bundleOk = this.lines.every((l) => l.bundleValid !== false);
    }

    // ===================== CAPTURE =====================
    get isCapture() {
        return this.mode === 'capture';
    }
    get isPhoto() {
        return this.inputMethod === 'photo';
    }
    get isFile() {
        return this.inputMethod === 'file';
    }
    get isVoice() {
        return this.inputMethod === 'voice';
    }
    get isManual() {
        return this.inputMethod === 'manual';
    }
    get isUpload() {
        return this.isPhoto || this.isFile;
    }
    get acceptedFormats() {
        if (this.isPhoto) {
            return ['.jpg', '.jpeg', '.png', '.heic', '.webp'];
        }
        if (this.isFile) {
            return ['.xlsx', '.xls', '.csv', '.pdf'];
        }
        return ['.m4a', '.mp3', '.wav', '.webm', '.ogg'];
    }
    // native <input type="file"> wants a comma-separated string, not an array
    get acceptAttr() {
        return this.acceptedFormats.join(',');
    }
    get chooseLabel() {
        if (this.isPhoto) {
            return 'Choose a Photo';
        }
        if (this.isFile) {
            return 'Choose a File';
        }
        return 'Attach an Audio File';
    }
    get uploadLabel() {
        if (this.isPhoto) {
            return 'Take or choose a photo of your list';
        }
        if (this.isFile) {
            return 'Choose an Excel, CSV or PDF';
        }
        return 'Attach a voice note';
    }
    get busy() {
        // Spinner only during the brief in-card async work (holder create / save).
        // Once the launch message is sent the card's job is done — don't spin forever
        // waiting on the agent, whose result arrives as a separate chat message.
        return this.captureStatus === 'saving' || this.captureStatus === 'analyzing';
    }
    get busyText() {
        return this.captureStatus === 'analyzing' ? 'Reading your order…' : 'Saving…';
    }
    get isSent() {
        return this.captureStatus === 'sent';
    }
    get recordDisabled() {
        return this.busy;
    }
    get recordLabel() {
        return this.isRecording ? 'Stop Recording' : 'Start Recording';
    }
    get recordClass() {
        return this.isRecording ? 'de-ot-rec de-ot-rec-on' : 'de-ot-rec';
    }

    // ----- live caption display -----
    get captionText() {
        return (this.liveFinal + ' ' + this.liveInterim).replace(/\s+/g, ' ').trim();
    }
    get showCaption() {
        // show while recording (even before words arrive) or whenever we have captured text
        return this.isVoice && (this.isRecording || this.captionText.length > 0);
    }
    get captionPlaceholder() {
        return this.isRecording && !this.captionText ? 'Listening… start speaking your order' : '';
    }

    // ----- photo / order-sheet / audio-note upload -----
    // A chat GUEST user cannot create Salesforce Files at all (hard license limit), so we do NOT
    // use lightning-file-upload. Instead we read the chosen file in the browser, base64-encode it
    // (downscaling photos to fit), split it into field-sized chunk rows via saveFileChunk, and let
    // Analyze Order (as the agent user) reassemble + decode them into an agent-owned ContentVersion
    // for the prompt/flow — the same guest-safe child-record mechanism the text paths use.
    @track selectedFileName = '';

    get uploadTargetReady() {
        return !!this.targetRecordId;
    }

    triggerFilePicker() {
        const input = this.template.querySelector('.de-ot-fileinput');
        if (input) {
            input.click();
        }
    }

    async handleFileSelected(event) {
        const file = event.target && event.target.files && event.target.files[0];
        if (!file) {
            return;
        }
        this.selectedFileName = file.name;
        this.errorMessage = '';
        this.captureStatus = 'saving';
        try {
            const base64 = this.isPhoto
                ? await this.downscaleImageToBase64(file)
                : await this.blobToBase64(file);

            if (!base64) {
                throw new Error('empty');
            }
            if (base64.length > MAX_TOTAL_B64) {
                this.captureStatus = 'idle';
                this.errorMessage = this.isPhoto
                    ? 'That photo is too large even after shrinking — please try a smaller or clearer photo.'
                    : 'That file is too large to send through chat (about 1.8 MB max). Please attach a smaller file, or type your items.';
                return;
            }

            await this.saveInChunks(base64, file.name);
            this.captureStatus = 'sent';
            this.sendMessageToChat(this.readyMessage());
        } catch (e) {
            this.captureStatus = 'idle';
            this.errorMessage = 'Could not read that file — please try another, or type your items.';
        } finally {
            // allow re-selecting the same file name
            if (event.target) {
                event.target.value = null;
            }
        }
    }

    // Split the base64 into field-sized slices and persist each as a chunk row sharing one upload
    // id. Saved sequentially so ordering is deterministic and we don't fan out many Apex calls at
    // once; Analyze Order reassembles them server-side. A small file is just one chunk.
    async saveInChunks(base64, fileName) {
        const uploadId = `${Date.now()}-${Math.floor(Math.random() * 1e9)}`;
        const total = Math.ceil(base64.length / B64_CHUNK);
        for (let i = 0; i < total; i++) {
            const slice = base64.substring(i * B64_CHUNK, (i + 1) * B64_CHUNK);
            // eslint-disable-next-line no-await-in-loop
            await saveFileChunk({
                recordId: this.targetRecordId,
                uploadId,
                fileName,
                seq: i,
                total,
                base64Chunk: slice
            });
        }
    }

    // Read a File/Blob into a bare base64 string (no data: prefix) for the Apex LongText field.
    blobToBase64(blob) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => {
                const result = reader.result || '';
                const comma = result.indexOf(',');
                resolve(comma >= 0 ? result.substring(comma + 1) : result);
            };
            reader.onerror = () => reject(reader.error || new Error('read failed'));
            reader.readAsDataURL(blob);
        });
    }

    // Downscale a photo on a canvas until its base64 fits under MAX_B64_CHARS. The order sheet
    // only needs to be legible to the OCR prompt, so progressively smaller/lower-quality JPEGs
    // are fine and keep us within the LongText cap.
    async downscaleImageToBase64(file) {
        const dataUrl = await new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => resolve(reader.result);
            reader.onerror = () => reject(reader.error || new Error('read failed'));
            reader.readAsDataURL(file);
        });
        const img = await new Promise((resolve, reject) => {
            const image = new Image();
            image.onload = () => resolve(image);
            image.onerror = () => reject(new Error('image decode failed'));
            image.src = dataUrl;
        });

        const steps = [
            { max: 1280, q: 0.7 },
            { max: 1024, q: 0.6 },
            { max: 800, q: 0.5 },
            { max: 640, q: 0.45 }
        ];
        let best = '';
        for (const step of steps) {
            const scale = Math.min(1, step.max / Math.max(img.width, img.height));
            const w = Math.max(1, Math.round(img.width * scale));
            const h = Math.max(1, Math.round(img.height * scale));
            const canvas = document.createElement('canvas');
            canvas.width = w;
            canvas.height = h;
            canvas.getContext('2d').drawImage(img, 0, 0, w, h);
            const out = canvas.toDataURL('image/jpeg', step.q);
            const comma = out.indexOf(',');
            best = comma >= 0 ? out.substring(comma + 1) : out;
            if (best.length <= MAX_B64_CHARS) {
                return best;
            }
        }
        return best; // smallest we could produce; caller enforces the cap
    }

    readyMessage() {
        if (this.isVoice) {
            return "I've uploaded my voice note — please listen to it and build my order table.";
        }
        if (this.isPhoto) {
            return "I've uploaded a photo of my order — please read it and build my order table.";
        }
        return "I've uploaded my order file — please read it and build my order table.";
    }

    // ----- voice recording: the live on-device transcript IS the order (no audio upload, no STT) -----
    async toggleRecording() {
        if (this.isRecording) {
            this.stopRecording();
        } else {
            this.startRecording();
        }
    }

    startRecording() {
        this.errorMessage = '';
        this.liveFinal = '';
        this.liveInterim = '';
        this.startLiveCaption();
        if (!this.speechSupported) {
            this.errorMessage =
                'Live transcription is not available on this browser — please attach a voice note instead.';
            return;
        }
        this.isRecording = true;
        this.captureStatus = 'recording';
    }

    stopRecording() {
        this.isRecording = false;
        this.stopLiveCaption();
        const transcript = this.captionText;
        if (!transcript) {
            this.captureStatus = 'idle';
            this.errorMessage =
                "I didn't catch any words — please try again, or attach a voice note.";
            return;
        }
        this.saveTranscript(transcript);
    }

    async saveTranscript(transcript) {
        this.captureStatus = 'saving';
        try {
            await saveVoiceText({ recordId: this.targetRecordId, transcript });
            this.captureStatus = 'sent';
            this.sendMessageToChat("I've read out my order — please build my order table.");
        } catch (e) {
            this.errorMessage = 'Could not save your order. Please try again.';
            this.captureStatus = 'idle';
        }
    }

    // ----- live caption via Web Speech API (display aid only; graceful no-op if unsupported) -----
    startLiveCaption() {
        try {
            const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
            if (!SR) {
                this.speechSupported = false;
                return; // recording still works; caption just won't show
            }
            this.speechSupported = true;
            const rec = new SR();
            rec.lang = 'en-IN';
            rec.continuous = true;
            rec.interimResults = true;
            rec.onresult = (event) => {
                let interim = '';
                let finalAdd = '';
                for (let i = event.resultIndex; i < event.results.length; i++) {
                    const chunk = event.results[i][0].transcript;
                    if (event.results[i].isFinal) {
                        finalAdd += chunk + ' ';
                    } else {
                        interim += chunk;
                    }
                }
                if (finalAdd) {
                    this.liveFinal = (this.liveFinal + ' ' + finalAdd).replace(/\s+/g, ' ').trim();
                }
                this.liveInterim = interim;
            };
            rec.onerror = () => {
                // mic/permission/network hiccup — leave whatever we have, keep recording
            };
            rec.onend = () => {
                // auto-restart while the user is still recording (SR can stop on pauses)
                if (this.isRecording && this.speechRecognition) {
                    try {
                        this.speechRecognition.start();
                    } catch (e) {
                        // already starting/stopped; ignore
                    }
                }
            };
            this.speechRecognition = rec;
            rec.start();
        } catch (e) {
            this.speechSupported = false;
        }
    }

    stopLiveCaption() {
        this.liveInterim = '';
        if (this.speechRecognition) {
            const rec = this.speechRecognition;
            this.speechRecognition = null; // prevents onend auto-restart
            try {
                rec.stop();
            } catch (e) {
                // ignore
            }
        }
    }

    // ----- manual catalogue search -----
    // Matches on BOTH the product name and the SKU/product code, so a dealer who knows the code
    // can type it directly. Each result also surfaces the code and the bundle size so the choice
    // is unambiguous.
    get filteredCatalogue() {
        const term = (this.searchTerm || '').toLowerCase().trim();
        const picked = new Set(this.manualItems.map((i) => i.sku));
        return this.catalogue
            .filter((c) => !picked.has(c.sku))
            .filter((c) => !term || String(c.name).toLowerCase().includes(term) || String(c.sku).toLowerCase().includes(term))
            .slice(0, 6)
            .map((c) => {
                const bundle = Number(c.bundle) || 1;
                const rateText = c.rateText || this.inr(c.rate);
                return {
                    ...c,
                    rateText,
                    metaText: `${c.pack} · ${rateText}`,
                    bundleText: bundle > 1 ? `Bundle of ${bundle}` : 'Sold singly'
                };
            });
    }
    get hasManualItems() {
        return this.manualItems.length > 0;
    }
    get manualRows() {
        return this.manualItems.map((i) => {
            const bundle = Number(i.bundle) || 1;
            return {
                ...i,
                valueText: this.inr(i.qty * i.rate),
                bundleText: bundle > 1 ? `(bundle of ${bundle})` : ''
            };
        });
    }
    get manualDoneDisabled() {
        return this.busy || !this.manualItems.length;
    }
    handleSearch(event) {
        this.searchTerm = event.target.value;
    }
    handleAddManual(event) {
        const sku = event.currentTarget.dataset.sku;
        const p = this.catalogue.find((c) => c.sku === sku);
        if (!p) {
            return;
        }
        // Start at one whole bundle so manual picks are only ever added in valid multiples.
        const bundle = Number(p.bundle) || 1;
        this.manualItems = [...this.manualItems, { sku, name: p.name, pack: p.pack, rate: p.rate, bundle, qty: bundle }];
        this.searchTerm = '';
    }
    handleManualInc(event) {
        this.adjustManual(event.currentTarget.dataset.sku, 1);
    }
    handleManualDec(event) {
        this.adjustManual(event.currentTarget.dataset.sku, -1);
    }
    handleManualRemove(event) {
        const sku = event.currentTarget.dataset.sku;
        this.manualItems = this.manualItems.filter((i) => i.sku !== sku);
    }
    adjustManual(sku, delta) {
        // Step in whole bundles; dropping below one bundle removes the item.
        this.manualItems = this.manualItems
            .map((i) => {
                if (i.sku !== sku) {
                    return i;
                }
                const step = Number(i.bundle) || 1;
                return { ...i, qty: i.qty + delta * step };
            })
            .filter((i) => i.qty > 0);
    }
    async handleManualDone() {
        if (!this.manualItems.length) {
            return;
        }
        this.captureStatus = 'saving';
        try {
            const itemsJSON = JSON.stringify(this.manualItems.map((i) => ({ sku: i.sku, qty: i.qty })));
            await saveManual({ recordId: this.targetRecordId, itemsJSON });
            this.captureStatus = 'sent';
            this.sendMessageToChat("I've added my items — please build my order table.");
        } catch (e) {
            this.errorMessage = 'Could not save your items. Please try again.';
            this.captureStatus = 'idle';
        }
    }

    // ===================== TABLE =====================
    get units() {
        return this.lines.reduce((s, l) => s + Number(l.qty), 0);
    }
    get orderValue() {
        return this.lines.reduce((s, l) => s + Number(l.value), 0);
    }
    get productCount() {
        return this.lines.length;
    }
    get valueText() {
        return this.inr(this.orderValue);
    }
    get footerText() {
        return `${this.units} units  ·  ${this.inr(this.orderValue)}`;
    }
    get totalPages() {
        return Math.max(1, Math.ceil(this.lines.length / this.rowsPerPage));
    }
    get pageLabel() {
        return `Page ${this.page} of ${this.totalPages}`;
    }
    get pagedRows() {
        const start = (this.page - 1) * this.rowsPerPage;
        return this.lines.slice(start, start + this.rowsPerPage).map((l) => {
            const badBundle = l.bundleValid === false;
            let rowClass = 'de-ot-row';
            if (badBundle) {
                rowClass = 'de-ot-row de-ot-row-badbundle';
            } else if (l.flagged && !this.flagResolved) {
                rowClass = 'de-ot-row de-ot-row-flagged';
            }
            const bundle = Number(l.bundle) || 1;
            return {
                ...l,
                valueText: this.inr(l.value),
                rateText: this.inr(l.rate),
                // Buy-quantity shown in brackets after the price on EVERY row, so the dealer is
                // mindful of the multiple before they adjust qty (not only on the flagged rows).
                bundleText: bundle > 1 ? `(bundle of ${bundle})` : '',
                badBundle,
                bundleHint: badBundle ? `Only in bundles of ${l.bundle}` : '',
                rowClass
            };
        });
    }
    // Bundle validation banner (blocks "Confirm & Continue" until cleared).
    get showBundleWarning() {
        return this.mode === 'table' && !this.notFound && !this.bundleOk;
    }
    get bundleWarningText() {
        return this.bundleMessage ||
            'Some items need a valid bundle size — use + / − on the highlighted rows, then confirm.';
    }
    get showTable() {
        return this.mode === 'table' && !this.notFound && this.lines.length;
    }
    get showEmpty() {
        return this.mode === 'table' && this.notFound;
    }
    get showSource() {
        // Source badge ("✓ Read from your file") intentionally hidden — kept wired for debugging only.
        return false;
    }
    get sourceText() {
        return '✓ Read from your file';
    }
    get sourceClass() {
        return 'de-ot-src de-ot-src-ok';
    }
    get showFlag() {
        return this.flagQuestion && !this.flagResolved;
    }
    get disablePrev() {
        return this.page <= 1;
    }
    get disableNext() {
        return this.page >= this.totalPages;
    }
    handlePrev() {
        if (this.page > 1) {
            this.page -= 1;
        }
    }
    handleNext() {
        if (this.page < this.totalPages) {
            this.page += 1;
        }
    }
    handleInc(event) {
        this.adjustQty(event.currentTarget.dataset.sku, 1);
    }
    handleDec(event) {
        this.adjustQty(event.currentTarget.dataset.sku, -1);
    }
    // Move the quantity to the NEAREST valid bundle in the chosen direction — never a non-multiple,
    // never below one bundle. E.g. for a product sold in bundles of 4 at qty 3: "+" snaps to 4 (the
    // next viable value, not 7), and from 4 the next "+" jumps to 8; "−" steps back one whole bundle.
    // Then recompute validity and persist the correction to the server-side basket.
    adjustQty(sku, delta) {
        let changed = null;
        this.lines = this.lines.map((l) => {
            if (l.sku === sku) {
                const step = Number(l.bundle) || 1;
                const cur = Number(l.qty);
                let q;
                if (delta > 0) {
                    // smallest whole bundle strictly greater than the current qty
                    q = (Math.floor(cur / step) + 1) * step;
                } else {
                    // largest whole bundle strictly less than the current qty, floored at one bundle
                    q = Math.max(step, (Math.ceil(cur / step) - 1) * step);
                }
                changed = { ...l, qty: q, value: q * Number(l.rate), bundleValid: step <= 1 || q % step === 0 };
                return changed;
            }
            return l;
        });
        this.recomputeBundle();
        if (changed) {
            this.persistLineQty(changed.sku, changed.qty);
        }
    }
    // Fire-and-forget persist of a corrected quantity; the card UI already reflects the change,
    // so a transient server hiccup must not block the dealer from continuing to adjust.
    persistLineQty(sku, qty) {
        setBasketLineQty({ sku, qty }).catch(() => {
            // keep the on-screen value; the server read-back on Confirm will re-validate
        });
    }
    handleConfirmFlag() {
        this.flagResolved = true;
        this.sendMessageToChat('Yes, that’s right');
    }
    handleChangeFlag() {
        this.sendMessageToChat('Change it');
    }

    // ----- next-step buttons -----
    get hasNextActions() {
        return this.nextActions.length > 0;
    }
    // Decorate the raw actions with their final CSS class + disabled state. A 'block' action
    // (Confirm & Continue) is disabled while any bundle is invalid, so the dealer cannot move
    // ahead until every quantity is a whole bundle.
    get decoratedActions() {
        return this.nextActions.map((a) => {
            const disabled = a.block && !this.bundleOk;
            const base = a.variant === 'secondary' ? 'de-ot-btn de-ot-btn-secondary' : 'de-ot-btn de-ot-btn-primary';
            return {
                ...a,
                disabled,
                cls: disabled ? base + ' de-ot-btn-disabled' : base
            };
        });
    }
    handleNextAction(event) {
        if (event.currentTarget.disabled) {
            return;
        }
        const msg = event.currentTarget.dataset.message;
        if (msg) {
            this.sendMessageToChat(msg);
        }
    }

    // ===================== shared helpers =====================
    inr(amount) {
        const n = Math.round(Number(amount) || 0);
        const s = String(Math.abs(n));
        let out;
        if (s.length <= 3) {
            out = s;
        } else {
            const last3 = s.slice(-3);
            let rest = s.slice(0, -3);
            let grouped = '';
            while (rest.length > 2) {
                grouped = ',' + rest.slice(-2) + grouped;
                rest = rest.slice(0, -2);
            }
            out = rest + grouped + ',' + last3;
        }
        return '₹' + (n < 0 ? '-' : '') + out;
    }

    sendMessageToChat(message) {
        if (!message) {
            return;
        }
        try {
            if (
                typeof embeddedservice_configuration !== 'undefined' &&
                embeddedservice_configuration.util &&
                embeddedservice_configuration.util.sendTextMessage
            ) {
                embeddedservice_configuration.util.sendTextMessage(message).catch(() => {});
            }
        } catch (e) {
            // silent in non-embedded contexts (builder preview)
        }
    }
}