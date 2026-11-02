import { LightningElement, api, track } from 'lwc';
import { revealCard } from 'c/de_cardReveal';
import addRecommendedItems from '@salesforce/apex/de_OrderCaptureController.addRecommendedItems';

const SECURED_BADGE = 'GOLD ✓';
const SECURED_REWARD = 'Credit note ₹15,100 secured';
const SECURED_DETAIL = '₹5.03 L of ₹5.00 L';

export default class De_schemeBoosters extends LightningElement {
    _value;
    _revealed = false;
    @track heading = '';
    @track items = [];
    @track targetScheme = null;
    @track remainingGap = 0;
    @track boosted = false;
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
            this.boosted = !!data.boosted;

            const list = Array.isArray(data.items) ? data.items : [];
            this.items = list.map((it, idx) => {
                const numericValue = this.toNumber(it.valueText);
                return {
                    key: it.sku || `item-${idx}`,
                    sku: it.sku || '',
                    name: it.name || '',
                    pack: it.pack || '',
                    qty: it.qty,
                    valueText: it.valueText || '',
                    qtyValueLabel: `× ${it.qty} · ${it.valueText}`,
                    note: it.note || '',
                    numericValue,
                    added: false,
                    btnLabel: 'Add'
                };
            });

            const gapNumber = Number(data.gap) || 0;
            this.remainingGap = this.boosted ? 0 : gapNumber;

            const ts = data.targetScheme || {};
            this.targetScheme = {
                name: ts.name || '',
                status: ts.status || 'within_reach',
                badge: ts.badge || '',
                detail: ts.detail || '',
                reward: ts.reward || ''
            };

            this.errorMessage = '';
        } catch (e) {
            this.errorMessage = 'Could not load boosters.';
        }
    }

    toNumber(valueText) {
        if (!valueText) { return 0; }
        const digits = String(valueText).replace(/[^0-9]/g, '');
        return digits ? parseInt(digits, 10) : 0;
    }

    formatInr(num) {
        const n = Math.max(0, Math.round(num));
        return `₹${n.toLocaleString('en-IN')}`;
    }

    get isSecured() {
        return this.boosted || this.remainingGap <= 0;
    }

    get gapRemainingText() {
        return `Gap Remaining: ${this.formatInr(this.remainingGap)}`;
    }

    get schemeStatus() {
        return this.isSecured ? 'secured' : (this.targetScheme ? this.targetScheme.status : 'within_reach');
    }

    get schemeCardClass() {
        return `target-scheme-card status-${this.schemeStatus}`;
    }

    get displayBadge() {
        if (!this.targetScheme) { return ''; }
        return this.isSecured ? SECURED_BADGE : this.targetScheme.badge;
    }

    get displayDetail() {
        if (!this.targetScheme) { return ''; }
        return this.isSecured ? SECURED_DETAIL : this.targetScheme.detail;
    }

    get displayReward() {
        if (!this.targetScheme) { return ''; }
        return this.isSecured ? SECURED_REWARD : this.targetScheme.reward;
    }

    get targetSchemeName() {
        return this.targetScheme ? this.targetScheme.name : '';
    }

    handleAddItem(event) {
        const key = event.currentTarget.dataset.key;
        const item = this.items.find((i) => i.key === key);
        if (!item || item.added) { return; }
        this.addItems([item]);
    }

    handleAddBoth() {
        const pending = this.items.filter((i) => !i.added);
        if (!pending.length) { return; }
        this.addItems(pending);
    }

    // Persist the chosen booster products into the order server-side (deterministic, same path as
    // the recommendations carousel) BEFORE posting a chat message, so the slab is genuinely secured
    // and the products reach the final order — never relying on the planner to run an add action.
    async addItems(toAdd) {
        if (this.adding || !toAdd.length) { return; }
        this.adding = true;
        const keys = new Set(toAdd.map((i) => i.key));
        const payload = toAdd.map((i) => ({ sku: i.sku, qty: i.qty }));
        const summary = toAdd.map((i) => `${i.name} ${i.pack} (${i.qty})`).join(', ');
        try {
            await addRecommendedItems({ itemsJSON: JSON.stringify(payload) });
            let gap = this.remainingGap;
            this.items = this.items.map((i) => {
                if (!keys.has(i.key)) { return i; }
                gap = Math.max(0, gap - i.numericValue);
                return { ...i, added: true, btnLabel: 'Added ✓' };
            });
            this.remainingGap = gap;
            // Phrase as an ORDER update (not a "scheme" message) so the router keeps this in the
            // ordering journey — a message mentioning "scheme" gets routed to the view-only My
            // Schemes subagent, which can't handle an add and dead-ends on the generic fallback.
            this.sendMessageToChat(
                `I've added the booster products to my order: ${summary}. Please show my updated order so I can review and place it.`
            );
        } catch (e) {
            this.errorMessage = 'Could not add those products. Please try again.';
            this.adding = false;
        }
    }

    handleNotNow() {
        this.sendMessageToChat('No thanks — take me to the final review so I can place my order.');
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