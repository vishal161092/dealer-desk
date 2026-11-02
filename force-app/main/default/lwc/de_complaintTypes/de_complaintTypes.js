import { LightningElement, api, track } from 'lwc';
import { revealCard } from 'c/de_cardReveal';

export default class De_complaintTypes extends LightningElement {
    _value;
    _revealed = false;
    @track heading = '';
    @track chips = [];
    errorMessage = '';

    @api
    get value() { return this._value; }
    set value(v) { this._value = v; this.parseValue(); }

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
        if (!v) { return; }
        const raw = v.dataJSON ? v.dataJSON : v;
        try {
            const data = typeof raw === 'string' ? JSON.parse(raw) : raw;
            this.heading = data.heading || '';
            this.chips = (data.chips || []).map((chip, index) => ({
                id: `${chip}-${index}`,
                label: chip
            }));
            this.errorMessage = '';
        } catch (e) {
            this.errorMessage = 'Could not load.';
        }
    }

    handleChipClick(event) {
        const id = event.currentTarget.dataset.id;
        const chip = this.chips.find((c) => c.id === id);
        if (chip) {
            this.sendMessageToChat(chip.label);
        }
    }

    sendMessageToChat(message) {
        if (!message) { return; }
        try {
            if (typeof embeddedservice_configuration !== 'undefined' &&
                embeddedservice_configuration.util &&
                embeddedservice_configuration.util.sendTextMessage) {
                embeddedservice_configuration.util.sendTextMessage(message).catch(() => {});
            }
        } catch (e) { /* silent in builder preview */ }
    }
}