import { LightningElement, api, track } from 'lwc';
import { revealCard } from 'c/de_cardReveal';

export default class De_ticketCard extends LightningElement {
    _value;
    _revealed = false;
    @track caseNumber = '';
    @track type = '';
    @track priority = '';
    @track status = '';
    @track orderNumber = '';
    @track owner = '';
    @track ownerTitle = '';
    @track sla = '';
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

    get titleLine() {
        return `Ticket ${this.caseNumber} Created`;
    }

    get metaLine() {
        return `${this.type} · Priority ${this.priority} · ${this.status}`;
    }

    get orderLine() {
        return `Order ${this.orderNumber}`;
    }

    parseValue() {
        const v = this._value;
        if (!v) {
            return;
        }
        const raw = v.dataJSON ? v.dataJSON : v;
        try {
            const data = typeof raw === 'string' ? JSON.parse(raw) : raw;
            this.caseNumber = data.caseNumber || '';
            this.type = data.type || '';
            this.priority = data.priority || '';
            this.status = data.status || '';
            this.orderNumber = data.orderNumber || '';
            this.owner = data.owner || '';
            this.ownerTitle = data.ownerTitle || '';
            this.sla = data.sla || '';
            this.errorMessage = '';
        } catch (e) {
            this.errorMessage = 'Could not load.';
        }
    }

    handleTrack() {
        this.sendMessageToChat('Track this ticket');
    }

    handleNote() {
        this.sendMessageToChat('Add a note');
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