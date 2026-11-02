/**
 * Shared "reveal" behaviour for the Agentforce custom Lightning Type cards.
 *
 * When a card mounts in the chat transcript it (1) scrolls itself into view and
 * (2) pulses a brief highlight ring, so the dealer never has to scroll the chat
 * widget to find the freshly-rendered card.
 *
 * This runs INSIDE the chat iframe (same document as the card), so — unlike the
 * host-page avatar CSS — there is no cross-origin barrier: a card can freely
 * scroll and style itself.
 *
 * Usage from a card component (call once, after its data has arrived):
 *     import { revealCard } from 'c/de_cardReveal';
 *     renderedCallback() {
 *         if (this._revealed || !this._value) return;
 *         this._revealed = true;
 *         revealCard(this.template);
 *     }
 */
// Subtle focus glow (Salesforce blue #0176d3). Deliberately NOT red — a red ring reads as an
// error, which this is not; it's just a gentle "here's the new card" cue.
const RING = 'rgba(1, 118, 211, ';

export function revealCard(shadowRoot) {
    if (!shadowRoot) {
        return;
    }
    // The first <div> in every card template is its visual root wrapper.
    const el = shadowRoot.querySelector('div');
    if (!el) {
        return;
    }

    // Defer briefly so the card has settled to its final height before we
    // scroll/measure (card content and totals render asynchronously).
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    setTimeout(() => {
        try {
            el.scrollIntoView({ behavior: 'smooth', block: 'center' });
        } catch (e) {
            // Older engines: fall back to a plain jump.
            el.scrollIntoView();
        }

        if (typeof el.animate === 'function') {
            el.animate(
                [
                    { boxShadow: `0 0 0 0 ${RING}0)` },
                    { boxShadow: `0 0 0 4px ${RING}0.22)`, offset: 0.3 },
                    { boxShadow: `0 0 0 4px ${RING}0)` }
                ],
                { duration: 1400, easing: 'ease-out' }
            );
        }
    }, 60);
}