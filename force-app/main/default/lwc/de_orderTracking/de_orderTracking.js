import { LightningElement, api, track } from 'lwc';
import { revealCard } from 'c/de_cardReveal';

const TONE_PILL_CLASS = {
    processing: 'status-pill status-pill-processing',
    transit: 'status-pill status-pill-transit',
    delivered: 'status-pill status-pill-delivered'
};

export default class De_orderTracking extends LightningElement {
    _value;
    _revealed = false;
    @track heading = '';
    @track orders = [];
    @track actions = [];
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
            this.heading = data.heading || '';
            this.orders = (data.orders || []).map((o, idx) => ({
                key: `${o.orderNumber || idx}`,
                orderNumber: o.orderNumber,
                status: o.status,
                valueText: o.valueText,
                products: o.products,
                detail: o.detail,
                tone: o.tone,
                pillClass: TONE_PILL_CLASS[o.tone] || 'status-pill',
                subLine: `${o.products} · ${o.valueText}`
            }));
            // Optional action-button bar (shown on the just-placed order card). Each carries the
            // chat message to post when tapped. The card itself is NOT clickable anymore.
            this.actions = (data.actions || []).map((a, idx) => ({
                key: `${a.label || idx}`,
                label: a.label,
                message: a.message
            }));
            this.errorMessage = '';
        } catch (e) {
            this.errorMessage = 'Could not load.';
        }
    }

    get hasActions() {
        return this.actions && this.actions.length > 0;
    }

    handleActionClick(event) {
        const message = event.currentTarget.dataset.message;
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