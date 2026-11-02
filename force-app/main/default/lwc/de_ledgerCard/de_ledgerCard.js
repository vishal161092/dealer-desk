import { LightningElement, api, track } from 'lwc';
import { revealCard } from 'c/de_cardReveal';

const TONE_AMOUNT_CLASS = {
    debit: 'amount amount-debit',
    credit: 'amount amount-credit'
};

export default class De_ledgerCard extends LightningElement {
    _value;
    _revealed = false;
    @track heading = '';
    @track limitText = '';
    @track usedText = '';
    @track availableText = '';
    @track utilisationPct = 0;
    @track entries = [];
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

    get utilisationLabel() {
        return `${this.utilisationPct}% used`;
    }

    get barFillStyle() {
        return `width: ${this.utilisationPct}%;`;
    }

    parseValue() {
        const v = this._value;
        if (!v) {
            return;
        }
        const raw = v.dataJSON ? v.dataJSON : v;
        try {
            const data = typeof raw === 'string' ? JSON.parse(raw) : raw;
            this.heading = data.heading || '';
            this.limitText = data.limitText || '';
            this.usedText = data.usedText || '';
            this.availableText = data.availableText || '';
            this.utilisationPct = data.utilisationPct || 0;
            this.entries = (data.entries || []).map((e, idx) => ({
                key: `${e.date || idx}-${idx}`,
                date: e.date,
                description: e.description,
                amountText: e.amountText,
                tone: e.tone,
                amountClass: TONE_AMOUNT_CLASS[e.tone] || 'amount'
            }));
            this.errorMessage = '';
        } catch (e) {
            this.errorMessage = 'Could not load.';
        }
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