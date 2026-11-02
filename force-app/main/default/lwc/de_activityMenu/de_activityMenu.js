import { LightningElement, api, track } from 'lwc';
import { revealCard } from 'c/de_cardReveal';

const ICON_MAP = {
    cart: '🛒',
    warning: '⚠️',
    truck: '🚚',
    award: '🏅',
    ledger: '📒'
};

export default class De_activityMenu extends LightningElement {
    _value;
    _revealed = false;
    @track heading = '';
    @track cards = [];
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
            this.cards = (data.cards || []).map((card, index) => ({
                id: `${card.value || card.title || 'card'}-${index}`,
                value: card.value,
                title: card.title,
                subtitle: card.subtitle,
                icon: ICON_MAP[card.icon] || '✨'
            }));
            this.errorMessage = '';
        } catch (e) {
            this.errorMessage = 'Could not load.';
        }
    }

    handleCardClick(event) {
        const id = event.currentTarget.dataset.id;
        const card = this.cards.find((c) => c.id === id);
        if (card) {
            this.sendMessageToChat(card.value);
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