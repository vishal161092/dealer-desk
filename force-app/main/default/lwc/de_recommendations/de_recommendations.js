import { LightningElement, api, track } from 'lwc';
import { revealCard } from 'c/de_cardReveal';
import addRecommendedItems from '@salesforce/apex/de_OrderCaptureController.addRecommendedItems';

export default class De_recommendations extends LightningElement {
    _value;
    _revealed = false;
    @track heading = 'Worth Adding to This Order';
    @track cards = [];
    errorMessage = '';
    adding = false;

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
            this.heading = data.heading || 'Worth Adding to This Order';
            this.cards = (data.cards || []).map((c) => {
                const bundle = Math.max(1, Number(c.bundle) || 1);
                const q = Math.max(bundle, Number(c.qty) || bundle);
                // Snap any out-of-step default up to a whole bundle so picks are always valid.
                const qty = q % bundle === 0 ? q : Math.ceil(q / bundle) * bundle;
                return {
                    sku: c.sku,
                    name: c.name,
                    pack: c.pack,
                    rate: c.rate,
                    rateText: c.rateText,
                    bundle,
                    qty,
                    reason: c.reason,
                    selected: false
                };
            });
            this.errorMessage = '';
        } catch (e) {
            this.errorMessage = 'Could not load recommendations.';
        }
    }

    // ---- derived ----
    get displayCards() {
        return this.cards.map((c) => ({
            ...c,
            cardClass: c.selected
                ? 'de-rec-card de-rec-card-selected'
                : 'de-rec-card'
        }));
    }
    get selectedCards() {
        return this.cards.filter((c) => c.selected);
    }
    get selectedCount() {
        return this.selectedCards.length;
    }
    get hasSelection() {
        return this.selectedCount > 0;
    }
    get addButtonLabel() {
        return `Add ${this.selectedCount} item${this.selectedCount === 1 ? '' : 's'}`;
    }

    // ---- interactions ----
    handleCardClick(event) {
        const sku = event.currentTarget.dataset.sku;
        this.cards = this.cards.map((c) =>
            c.sku === sku ? { ...c, selected: !c.selected } : c
        );
    }
    handleInc(event) {
        event.stopPropagation();
        this.adjustQty(event.currentTarget.dataset.sku, 1);
    }
    handleDec(event) {
        event.stopPropagation();
        this.adjustQty(event.currentTarget.dataset.sku, -1);
    }
    adjustQty(sku, delta) {
        this.cards = this.cards.map((c) => {
            if (c.sku === sku) {
                // Step in whole bundles, never below one bundle.
                const step = Number(c.bundle) || 1;
                const q = Math.max(step, Number(c.qty) + delta * step);
                return { ...c, qty: q };
            }
            return c;
        });
    }
    async handleAdd() {
        if (!this.hasSelection || this.adding) {
            return;
        }
        this.adding = true;
        // Persist the picks into the server-side basket FIRST (by SKU, so there is no name-parsing
        // guesswork), so the add is already done before the agent does anything. The agent then
        // only has to re-render the table — it can no longer skip the add.
        const items = this.selectedCards.map((c) => ({ sku: c.sku, qty: c.qty }));
        const summary = this.selectedCards
            .map((c) => `${c.name} ${c.pack} (${c.qty})`)
            .join(', ');
        try {
            await addRecommendedItems({ itemsJSON: JSON.stringify(items) });
            this.sendMessageToChat(
                `I've added these to my order: ${summary}. Please show my updated order.`
            );
        } catch (e) {
            this.errorMessage = 'Could not add those items. Please try again.';
            this.adding = false;
        }
    }
    handleNoThanks() {
        this.sendMessageToChat("No thanks — these are fine, let's continue.");
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