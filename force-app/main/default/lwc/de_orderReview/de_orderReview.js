import { LightningElement, api, track } from 'lwc';
import { revealCard } from 'c/de_cardReveal';

export default class De_orderReview extends LightningElement {
    _value;
    _revealed = false;
    @track title = 'Finished order';
    @track lines = [];
    rowsPerPage = 4;
    @track page = 1;
    @track summary = {
        orderValueText: '',
        benefitText: '',
        creditAvailText: '',
        remainingText: '',
        breaches: false
    };
    creditAvailable = 0;
    errorMessage = '';

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
            this.title = data.title || 'Finished order';
            this.rowsPerPage = data.rowsPerPage || 4;
            this.page = 1;
            this.lines = (data.lines || []).map((l) => ({
                n: l.n,
                sku: l.sku,
                name: l.name,
                pack: l.pack,
                qty: Number(l.qty) || 1,
                rate: Number(l.rate) || 0,
                flag: l.flag || ''
            }));
            this.summary = {
                orderValueText: (data.summary && data.summary.orderValueText) || '',
                benefitText: (data.summary && data.summary.benefitText) || '',
                creditAvailText: (data.summary && data.summary.creditAvailText) || '',
                remainingText: (data.summary && data.summary.remainingText) || '',
                breaches: !!(data.summary && data.summary.breaches)
            };
            this.creditAvailable = this.parseCurrencyDigits(this.summary.creditAvailText);
            this.errorMessage = '';
        } catch (e) {
            this.errorMessage = 'Could not load the order.';
        }
    }

    parseCurrencyDigits(text) {
        if (!text) {
            return 0;
        }
        const digits = String(text).replace(/[^0-9]/g, '');
        return digits ? Number(digits) : 0;
    }

    // ---- derived ----
    get units() {
        return this.lines.reduce((s, l) => s + Number(l.qty), 0);
    }
    get orderValue() {
        return this.lines.reduce((s, l) => s + Number(l.qty) * Number(l.rate), 0);
    }
    get productCount() {
        return this.lines.length;
    }
    get valueText() {
        return this.inr(this.orderValue);
    }
    get footerText() {
        return `${this.units} units · ${this.inr(this.orderValue)}`;
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
            const value = Number(l.qty) * Number(l.rate);
            return {
                ...l,
                valueText: this.inr(value),
                rateText: `${this.inr(l.rate)} each`
            };
        });
    }
    get disablePrev() {
        return this.page <= 1;
    }
    get disableNext() {
        return this.page >= this.totalPages;
    }

    get liveOrderValueText() {
        return this.inr(this.orderValue);
    }
    get liveRemaining() {
        return this.creditAvailable - this.orderValue;
    }
    get liveRemainingText() {
        return this.inr(this.liveRemaining);
    }
    get isBreaching() {
        return this.summary.breaches || (this.creditAvailable > 0 && this.liveRemaining < 0);
    }
    get creditLineClass() {
        return this.isBreaching ? 'de-or-credit-line de-or-credit-breach' : 'de-or-credit-line';
    }
    get showSplitOrder() {
        return this.isBreaching;
    }

    // ---- interactions ----
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
    adjustQty(sku, delta) {
        this.lines = this.lines.map((l) => {
            if (l.sku === sku) {
                const q = Math.max(1, Number(l.qty) + delta);
                return { ...l, qty: q };
            }
            return l;
        });
    }
    handleConfirm() {
        this.sendMessageToChat('Confirm & place order');
    }
    handleKeepEditing() {
        this.sendMessageToChat('Keep editing');
    }
    handleSplitOrder() {
        this.sendMessageToChat('Split the order');
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
}