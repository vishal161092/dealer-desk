import { LightningElement, api, track } from 'lwc';
import { revealCard } from 'c/de_cardReveal';
import addRecommendedItems from '@salesforce/apex/de_OrderCaptureController.addRecommendedItems';

export default class De_schemeCards extends LightningElement {
    _value;
    _revealed = false;
    @track heading = '';
    @track schemes = [];
    errorMessage = '';
    adding = false;

    @api
    get value() { return this._value; }
    set value(v) { this._value = v; this.parseValue(); }

    connectedCallback() { this.parseValue(); }

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
            const list = Array.isArray(data.schemes) ? data.schemes : [];
            this.schemes = list.map((s, idx) => {
                const status = s.status || 'out_of_reach';
                const progress = Math.max(0, Math.min(100, Number(s.progress) || 0));
                const boosterItems = Array.isArray(s.boosterItems) ? s.boosterItems : [];
                return {
                    key: s.name ? `${s.name}-${idx}` : `scheme-${idx}`,
                    name: s.name || '',
                    window: s.window || '',
                    status,
                    badge: s.badge || '',
                    progress,
                    detail: s.detail || '',
                    reward: s.reward || '',
                    boosterItems,
                    cardClass: `scheme-card status-${status}`,
                    barClass: `progress-fill status-${status}`,
                    barStyle: `width: ${progress}%;`,
                    // only offer the one-tap "add to secure" when we actually know which products close it
                    showBoosterButtons: status === 'within_reach',
                    canAddToSecure: status === 'within_reach' && boosterItems.length > 0,
                    added: false,
                    addLabel: 'Add Products to Secure'
                };
            });
            this.errorMessage = '';
        } catch (e) {
            this.errorMessage = 'Could not load schemes.';
        }
    }

    // True when at least one scheme is still within reach — i.e. the per-scheme booster buttons
    // ("Add Products to Secure" / "Show Boosters" / "Skip Schemes") are shown and already give the
    // dealer a forward path.
    get hasWithinReach() {
        return this.schemes.some((s) => s.status === 'within_reach');
    }

    // When NO scheme is within reach (every scheme is already secured or out of reach), the per-scheme
    // buttons never render, so the card otherwise dead-ends — the dealer has to type to move on and
    // hits the generic fallback. Show a single forward button so they can always proceed to review.
    get showFinalise() {
        return this.schemes.length > 0 && !this.hasWithinReach;
    }

    handleShowBoosters() {
        this.sendMessageToChat('Show boosters');
    }

    handleSkipSchemes() {
        this.sendMessageToChat('No thanks — take me to the final review so I can place my order.');
    }

    // Forward action shown when there's nothing left to boost (all schemes secured/out of reach).
    // Reuses the same review-routing message the ordering journey already handles, so it lands on the
    // final-review card where the dealer can place the order.
    handleFinalise() {
        this.sendMessageToChat('No thanks — take me to the final review so I can place my order.');
    }

    // One-tap "add the products that secure this scheme" — persists the booster products into the
    // order server-side (deterministic, like the recommendations carousel) BEFORE posting a chat
    // message, so the slab is genuinely secured and the items reach the final order even if the
    // planner never runs an add action.
    async handleAddToSecure(event) {
        if (this.adding) { return; }
        const key = event.currentTarget.dataset.key;
        const scheme = this.schemes.find((s) => s.key === key);
        if (!scheme || scheme.added || !scheme.boosterItems.length) { return; }

        this.adding = true;
        const items = scheme.boosterItems.map((it) => ({ sku: it.sku, qty: it.qty }));
        const summary = scheme.boosterItems
            .map((it) => `${it.name} ${it.pack} (${it.qty})`)
            .join(', ');
        try {
            await addRecommendedItems({ itemsJSON: JSON.stringify(items) });
            this.schemes = this.schemes.map((s) =>
                s.key === key ? { ...s, added: true, addLabel: 'Added ✓' } : s
            );
            // Phrase as an ORDER update (not a "scheme" message) so the router keeps this in the
            // ordering journey rather than the view-only My Schemes subagent (which dead-ends).
            this.sendMessageToChat(
                `I've added the booster products to my order for ${scheme.name}: ${summary}. Please show my updated order so I can review and place it.`
            );
        } catch (e) {
            this.errorMessage = 'Could not add those products. Please try again.';
            this.adding = false;
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
        } catch (e) { /* silent */ }
    }
}