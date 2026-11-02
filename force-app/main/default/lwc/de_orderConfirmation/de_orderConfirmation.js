import { LightningElement, api, track } from 'lwc';
import { revealCard } from 'c/de_cardReveal';

export default class De_orderConfirmation extends LightningElement {
    _value;
    _revealed = false;
    @track orderNumber = '';
    @track orderValueText = '';
    @track products = 0;
    @track units = 0;
    @track dispatchDate = '';
    @track depot = '';
    @track schemeCreditText = '';
    @track creditRemainingText = '';
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
            this.orderNumber = data.orderNumber || '';
            this.orderValueText = data.orderValueText || '';
            this.products = data.products || 0;
            this.units = data.units || 0;
            this.dispatchDate = data.dispatchDate || '';
            this.depot = data.depot || '';
            this.schemeCreditText = data.schemeCreditText || '';
            this.creditRemainingText = data.creditRemainingText || '';
            this.errorMessage = '';
        } catch (e) {
            this.errorMessage = 'Could not load the order confirmation.';
        }
    }

    get productsUnitsText() {
        return `${this.products} products · ${this.units} units`;
    }
    get dispatchText() {
        return `Dispatch ${this.dispatchDate} · ${this.depot}`;
    }

    handleTrackOrder() {
        this.sendMessageToChat('Track this order');
    }
    handleEmailCopy() {
        this.sendMessageToChat('Email me a copy');
    }
    handlePlaceAnother() {
        this.sendMessageToChat('Place another order');
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