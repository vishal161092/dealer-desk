import { LightningElement, api, track } from 'lwc';
import { revealCard } from 'c/de_cardReveal';

export default class De_orderProducts extends LightningElement {
    _value;
    _revealed = false;
    @track orderNumber = '';
    @track deliveredDate = '';
    @track productCount = 0;
    @track valueText = '';
    @track depot = '';
    @track question = '';
    @track products = [];
    errorMessage = '';

    // ---- inline "how many were short" capture (shown after a product is picked) ----
    @track selectedLabel = '';
    @track selectedKey = '';
    @track shortQty = 1;
    @track note = '';
    @track submitted = false;

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

    get metaLine() {
        return `${this.deliveredDate} · ${this.productCount} products`;
    }

    get valueLine() {
        return `${this.valueText} · ${this.depot}`;
    }

    // detail panel shows once a product is picked and before Submit
    get showDetail() {
        return !!this.selectedKey && !this.submitted;
    }

    get showChips() {
        return !this.submitted;
    }

    get decDisabled() {
        return this.shortQty <= 1;
    }

    get shortSummary() {
        const unit = this.shortQty === 1 ? 'unit' : 'units';
        return `${this.shortQty} ${unit} short`;
    }

    parseValue() {
        const v = this._value;
        if (!v) {
            return;
        }
        const raw = v.dataJSON ? v.dataJSON : v;
        try {
            const data = typeof raw === 'string' ? JSON.parse(raw) : raw;
            this.orderNumber = data.orderNumber || '';
            this.deliveredDate = data.deliveredDate || '';
            this.productCount = data.productCount || 0;
            this.valueText = data.valueText || '';
            this.depot = data.depot || '';
            this.question = data.question || '';
            this.products = (data.products || []).map((p, idx) => ({
                key: `${p.label || p.name || idx}-${idx}`,
                name: p.name,
                pack: p.pack,
                label: p.label,
                selected: false,
                chipClass: 'chip'
            }));
            this.errorMessage = '';
        } catch (e) {
            this.errorMessage = 'Could not load.';
        }
    }

    handleChipClick(event) {
        const key = event.currentTarget.dataset.key;
        const chosen = this.products.find((p) => p.key === key);
        if (!chosen) {
            return;
        }
        this.products = this.products.map((p) => {
            const isSelected = p.key === key;
            return {
                ...p,
                selected: isSelected,
                chipClass: isSelected ? 'chip chip-selected' : 'chip'
            };
        });
        // reveal the inline "how many were short" panel instead of sending now
        this.selectedKey = key;
        this.selectedLabel = chosen.label || chosen.name || '';
        this.shortQty = 1;
        this.note = '';
    }

    handleQtyInc() {
        this.shortQty = this.shortQty + 1;
    }

    handleQtyDec() {
        if (this.shortQty > 1) {
            this.shortQty = this.shortQty - 1;
        }
    }

    handleNoteChange(event) {
        this.note = event.target.value || '';
    }

    handleChangeProduct() {
        // let the dealer re-pick the affected product
        this.selectedKey = '';
        this.selectedLabel = '';
        this.shortQty = 1;
        this.note = '';
        this.products = this.products.map((p) => ({
            ...p,
            selected: false,
            chipClass: 'chip'
        }));
    }

    handleSubmitDetail() {
        if (!this.selectedKey) {
            return;
        }
        const unit = this.shortQty === 1 ? 'unit' : 'units';
        let message = `It was the ${this.selectedLabel} — ${this.shortQty} ${unit} short.`;
        const trimmedNote = (this.note || '').trim();
        if (trimmedNote) {
            message += ` Note: ${trimmedNote}`;
        }
        this.submitted = true;
        this.sendMessageToChat(message);
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
            /* silent */
        }
    }
}