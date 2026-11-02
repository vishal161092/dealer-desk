/**
 * de_DealerDemoCards
 * Builds the JSON payloads (dataJSON) for every card renderer in the Hueline Service Agent
 * demo, reading figures from de_DealerDemoData. Keeping them here keeps the action
 * classes thin and the numbers in one place (data pack section 7).
 */
public with sharing class de_DealerDemoCards {

    // ===== Step 1 — activity menu =====
    public static String activityMenuJSON() {
        List<Object> cards = new List<Object>{
            card('Place an order',  'Place an Order',   'Photo, voice, file or manual', 'cart'),
            card('Raise a complaint','Raise a Complaint','Quality, short supply, delay', 'warning'),
            card('Track an order',   'Track an Order',   '3 in transit',                 'truck'),
            card('My schemes',       'My Schemes',       '3 running this quarter',       'award'),
            card('Ledger & credit',  'Ledger & Credit',  '₹6,20,000 available',          'ledger')
        };
        return JSON.serialize(new Map<String, Object>{
            'heading' => 'What would you like to do today?',
            'cards'   => cards
        });
    }

    // ===== Step 3 — input methods =====
    public static String inputMethodsJSON() {
        List<Object> cards = new List<Object>{
            cta('Upload a photo',     'Upload a Photo',     'Handwritten or printed', 'Choose', 'image'),
            cta('Send a voice note',  'Send a Voice Note',  'Record or attach',       'Record', 'mic'),
            cta('Upload a file',      'Upload a File',      'Excel, CSV, PDF',        'Browse', 'file'),
            cta('Add items manually', 'Add Items Manually', 'Search the catalogue',   'Search', 'search')
        };
        return JSON.serialize(new Map<String, Object>{
            'heading' => 'How would you like to give me the order?',
            'cards'   => cards
        });
    }

    // ===== Step 7 — recommendations (data pack 7.5) =====
    public static String recommendationsJSON() {
        List<Object> cards = new List<Object>{
            rec('HL000000031', 10, 'You took 12 in August. Repaint season runs to mid-November.'),
            rec('HL000000020', 8,  'Your fastest mover. About 6 days of cover left.'),
            rec('HL000000030', 4,  'Painter scans in your area up 28% this month.'),
            rec('HL000000016', 3,  'Three premium projects registered nearby.')
        };
        return JSON.serialize(new Map<String, Object>{
            'heading' => 'Worth Adding to This Order',
            'cards'   => cards
        });
    }

    private static Map<String, Object> rec(String sku, Integer qty, String reason) {
        Map<String, Object> p = de_DealerDemoData.catalogue().get(sku);
        Integer rate = (Integer) p.get('rate');
        return new Map<String, Object>{
            'sku'    => sku,
            'name'   => p.get('name'),
            'pack'   => p.get('pack'),
            'rate'   => rate,
            'rateText' => de_DealerDemoData.inr(rate),
            'qty'    => qty,
            'bundle' => de_DealerDemoData.bundleOf(sku),
            'reason' => reason
        };
    }

    // ===== Step 10 — schemes =====
    public static String schemesJSON(Map<String, Object> basket) {
        Boolean boosted = isBoosted(basket);

        Map<String, Object> premium = new Map<String, Object>{
            'name'     => 'Premium Emulsion Growth',
            'window'   => '01 Aug – 15 Oct · 15 days left',
            'status'   => 'secured',
            'badge'    => 'PLATINUM ✓',
            'progress' => 100,
            'detail'   => '₹9.53 L of ₹9.50 L',
            'reward'   => 'Credit note ₹38,100 secured'
        };

        Map<String, Object> monsoon = boosted
            ? new Map<String, Object>{
                'name'     => 'Monsoon Shield Drive',
                'window'   => '01 Sep – 31 Oct',
                'status'   => 'secured',
                'badge'    => 'GOLD ✓',
                'progress' => 100,
                'detail'   => '₹5.03 L of ₹5.00 L',
                'reward'   => 'Credit note ₹15,100 secured'
              }
            : new Map<String, Object>{
                'name'     => 'Monsoon Shield Drive',
                'window'   => '01 Sep – 31 Oct',
                'status'   => 'within_reach',
                'badge'    => '₹1,04,000 to GOLD',
                'progress' => 79,
                'detail'   => '₹3.96 L of ₹5.00 L',
                'reward'   => '3% credit note ≈ ₹15,100 at stake',
                // The booster products that close this slab, so the scheme card itself can offer a
                // one-tap "add to secure" (persisted server-side) without needing the boosters card.
                'boosterItems' => new List<Object>{
                    boosterItem('HL000000031', 10),
                    boosterItem('HL000000029', 9)
                }
              };

        Map<String, Object> woodtech = new Map<String, Object>{
            'name'     => 'Woodtech Starter Bonus',
            'window'   => 'Not enrolled',
            'status'   => 'out_of_reach',
            'badge'    => 'NOT ENROLLED',
            'progress' => 12,
            'detail'   => '₹0.12 L of ₹1.00 L',
            'reward'   => 'Too far this quarter — worth planning for January'
        };

        return JSON.serialize(new Map<String, Object>{
            'heading' => 'Your Schemes This Quarter',
            'schemes' => new List<Object>{ premium, monsoon, woodtech }
        });
    }

    // ===== Step 11 — scheme boosters =====
    public static String boostersJSON(Map<String, Object> basket) {
        Boolean boosted = isBoosted(basket);
        List<Object> items = new List<Object>{
            booster('HL000000031', 10, '79,000', 'New line'),
            booster('HL000000029', 9,  '71,100', 'Already in basket at qty 5 · raises to 14')
        };
        Map<String, Object> target = boosted
            ? new Map<String, Object>{ 'name' => 'Monsoon Shield Drive', 'status' => 'secured',
                  'badge' => 'GOLD ✓', 'detail' => '₹5.03 L of ₹5.00 L', 'reward' => 'Credit note ₹15,100 secured' }
            : new Map<String, Object>{ 'name' => 'Monsoon Shield Drive', 'status' => 'within_reach',
                  'badge' => '₹1,04,000 to GOLD', 'detail' => '₹3.96 L of ₹5.00 L', 'reward' => '3% credit note ≈ ₹15,100 at stake' };
        return JSON.serialize(new Map<String, Object>{
            'heading'      => 'Two wall-putty lines close the ₹1,04,000 gap',
            'gap'          => 104000,
            'gapText'      => '₹1,04,000',
            'boosted'      => boosted,
            'items'        => items,
            'targetScheme' => target
        });
    }

    // Minimal {sku, qty, name, pack} descriptor for a booster, read from the catalogue so names
    // and packs stay in sync with the single source of truth.
    private static Map<String, Object> boosterItem(String sku, Integer qty) {
        Map<String, Object> p = de_DealerDemoData.catalogue().get(sku);
        return new Map<String, Object>{
            'sku'  => sku,
            'qty'  => qty,
            'name' => p.get('name'),
            'pack' => p.get('pack')
        };
    }

    private static Map<String, Object> booster(String sku, Integer qty, String valueText, String note) {
        Map<String, Object> p = de_DealerDemoData.catalogue().get(sku);
        return new Map<String, Object>{
            'sku'  => sku,
            'name' => p.get('name'),
            'pack' => p.get('pack'),
            'qty'  => qty,
            'valueText' => '₹' + valueText,
            'note' => note
        };
    }

    // ===== Step 12 — order review (basket + summary + credit) =====
    public static String orderReviewJSON(Map<String, Object> basket) {
        Long orderValue = de_DealerDemoData.asLong(basket.get('value'));
        Long benefit = schemeBenefit(basket);
        Long remaining = de_DealerDemoData.CREDIT_AVAIL - orderValue;
        Boolean breaches = orderValue > de_DealerDemoData.CREDIT_AVAIL;

        Map<String, Object> payload = new Map<String, Object>(basket);
        payload.put('title', 'Finished Order');
        payload.put('rowsPerPage', 4);
        payload.put('summary', new Map<String, Object>{
            'orderValueText' => de_DealerDemoData.inr(orderValue),
            'benefitText'    => de_DealerDemoData.inr(benefit),
            'creditAvailText'=> de_DealerDemoData.inr(de_DealerDemoData.CREDIT_AVAIL),
            'remainingText'  => de_DealerDemoData.inr(remaining),
            'breaches'       => breaches
        });
        return JSON.serialize(payload);
    }

    // ===== Step 13 — order confirmation (scripted demo values 7.7 / 7.8) =====
    public static String confirmationJSON(Map<String, Object> basket, String orderNumber) {
        Long orderValue = de_DealerDemoData.asLong(basket.get('value'));
        Long benefit = schemeBenefit(basket);
        Long remaining = de_DealerDemoData.CREDIT_AVAIL - orderValue;
        return JSON.serialize(new Map<String, Object>{
            'orderNumber'   => orderNumber,
            'orderValueText'=> de_DealerDemoData.inr(orderValue),
            'products'      => basket.get('products'),
            'units'         => basket.get('units'),
            'dispatchDate'  => '2 October 2026',
            'depot'         => de_DealerDemoData.DEPOT + ' depot',
            'schemeCreditText' => de_DealerDemoData.inr(benefit),
            'creditRemainingText' => de_DealerDemoData.inr(remaining)
        });
    }

    // ===== Service S1 — complaint types =====
    public static String complaintTypesJSON() {
        return JSON.serialize(new Map<String, Object>{
            'heading' => 'What’s the complaint about?',
            'chips'   => new List<String>{
                'Short Supply', 'Damaged in Transit', 'Shade Mismatch', 'Product Quality',
                'Delivery Delay', 'Billing / Invoice', 'Something Else'
            }
        });
    }

    // ===== Service S2 — pre-identified delivered order (data pack 7.8) =====
    public static String deliveredOrderJSON() {
        List<Object> products = new List<Object>{
            prodChip('HL GLOSSCOAT ENML BLACK 1 LT', '1 L'),
            prodChip('HL FIELDCOAT EMUL TE 1 20 LT', '20 L'),
            prodChip('Smoothset Wall Putty WHITE 20 KG', '20 KG'),
            prodChip('HL GLOSSCOAT ENML BROWN 4 LT', '4 L'),
            prodChip('HUELINE WALLPUTTY WHITE 5KG', '5 KG'),
            prodChip('HL FIELDCOAT EMUL SUPWHITE 4 LTR', '4 L')
        };
        return JSON.serialize(new Map<String, Object>{
            'orderNumber'  => 'HL-SO-2026-08702',
            'deliveredDate'=> 'Delivered 26 Sep 2026',
            'productCount' => 6,
            'valueText'    => '₹1,84,600',
            'depot'        => 'Bhosari depot',
            'question'     => 'Which product was short?',
            'products'     => products
        });
    }

    private static Map<String, Object> prodChip(String name, String pack) {
        return new Map<String, Object>{ 'name' => name, 'pack' => pack, 'label' => name + ' ' + pack };
    }

    // ===== Service S4 — ticket card (data pack 7.8) =====
    public static String ticketJSON(String caseNumber, String complaintType, String orderNumber) {
        return JSON.serialize(new Map<String, Object>{
            'caseNumber'    => caseNumber,
            'type'          => String.isBlank(complaintType) ? 'Short Supply' : complaintType,
            'priority'      => 'Medium',
            'status'        => 'New',
            'orderNumber'   => String.isBlank(orderNumber) ? 'HL-SO-2026-08702' : orderNumber,
            'owner'         => de_DealerDemoData.SERVICE_OFFICER,
            'ownerTitle'    => 'Territory Service Officer · Pune West',
            'sla'           => 'Response due within 24 hours'
        });
    }

    // ===== Track order =====
    // If the dealer just placed an order this session, Track shows ONLY that order with its REAL
    // counts/value (never the static demo rows). Otherwise it shows the static recent-orders list.
    public static String trackingJSON() {
        Map<String, Object> placed = de_OrderState.lastPlaced();
        if (placed != null) {
            return placedTrackingJSON(placed);
        }
        List<Object> orders = new List<Object>{
            trackRow('HL-SO-2026-08841', 'Processing', '₹4,67,350', '11 products', 'Dispatch 2 Oct · Bhosari depot', 'processing'),
            trackRow('HL-SO-2026-08798', 'In Transit', '₹2,14,500', '7 products',  'ETA 1 Oct · out for delivery',  'transit'),
            trackRow('HL-SO-2026-08702', 'Delivered',  '₹1,84,600', '6 products',  'Delivered 26 Sep · Bhosari depot','delivered')
        };
        return JSON.serialize(new Map<String, Object>{
            'heading' => 'Your Recent Orders',
            'orders'  => orders
        });
    }

    // The just-placed order as a single, non-clickable Track card with its own action buttons.
    private static String placedTrackingJSON(Map<String, Object> placed) {
        String orderNumber = String.valueOf(placed.get('orderNumber'));
        Object products = placed.get('products');
        Object units = placed.get('units');
        Long value = de_DealerDemoData.asLong(placed.get('value'));
        Map<String, Object> row = new Map<String, Object>{
            'orderNumber' => orderNumber,
            'status'      => 'Processing',
            'valueText'   => de_DealerDemoData.inr(value),
            'products'    => String.valueOf(products) + ' products · ' + String.valueOf(units) + ' units',
            'detail'      => 'Dispatch 2 October 2026 · ' + de_DealerDemoData.DEPOT + ' depot',
            'tone'        => 'processing'
        };
        return JSON.serialize(new Map<String, Object>{
            'heading' => 'Your Order',
            'orders'  => new List<Object>{ row },
            'actions' => new List<Object>{
                trackAction('Email a Copy',        'Email me a copy'),
                trackAction('Place Another Order', 'Place another order'),
                trackAction('Main Menu',           'Main menu')
            }
        });
    }

    // A Track-card action button: {label} shown on the button, {message} posted into chat on tap.
    private static Map<String, Object> trackAction(String label, String message) {
        return new Map<String, Object>{ 'label' => label, 'message' => message };
    }

    private static Map<String, Object> trackRow(String num, String status, String valueText, String products, String detail, String tone) {
        return new Map<String, Object>{
            'orderNumber' => num, 'status' => status, 'valueText' => valueText,
            'products' => products, 'detail' => detail, 'tone' => tone
        };
    }

    // ===== Ledger & credit =====
    public static String ledgerJSON() {
        List<Object> entries = new List<Object>{
            ledgerRow('26 Sep 2026', 'Invoice · HL-SO-2026-08702', '-₹1,84,600', 'debit'),
            ledgerRow('22 Sep 2026', 'Payment received · NEFT',    '+₹3,00,000', 'credit'),
            ledgerRow('18 Sep 2026', 'Credit note · Q2 scheme',    '+₹24,800',   'credit'),
            ledgerRow('12 Sep 2026', 'Invoice · HL-SO-2026-08655', '-₹2,96,000', 'debit')
        };
        Long util = de_DealerDemoData.CREDIT_USED;
        Long creditLimit = de_DealerDemoData.CREDIT_LIMIT;
        Integer pct = (Integer) Math.round((Double) util / (Double) creditLimit * 100);
        return JSON.serialize(new Map<String, Object>{
            'heading'        => 'Ledger & Credit',
            'limitText'      => de_DealerDemoData.inr(creditLimit),
            'usedText'       => de_DealerDemoData.inr(util),
            'availableText'  => de_DealerDemoData.inr(de_DealerDemoData.CREDIT_AVAIL),
            'utilisationPct' => pct,
            'entries'        => entries
        });
    }

    private static Map<String, Object> ledgerRow(String dt, String descr, String amountText, String tone) {
        return new Map<String, Object>{ 'date' => dt, 'description' => descr, 'amountText' => amountText, 'tone' => tone };
    }

    // ===== helpers =====
    // Scheme benefit secured on this order: ₹38,100 always + ₹15,100 once boosters close Gold.
    public static Long schemeBenefit(Map<String, Object> basket) {
        return isBoosted(basket) ? 53200L : 38100L;
    }

    // Boosters are "in" once Wall Putty 20 KG reaches qty 14, or the 40 KG line is on the order.
    public static Boolean isBoosted(Map<String, Object> basket) {
        List<Object> lines = (List<Object>) basket.get('lines');
        if (lines == null) { return false; }
        for (Object o : lines) {
            Map<String, Object> l = (Map<String, Object>) o;
            String sku = String.valueOf(l.get('sku'));
            Integer qty = Integer.valueOf(l.get('qty'));
            if (sku == 'HL000000031') { return true; }
            if (sku == 'HL000000029' && qty >= 14) { return true; }
        }
        return false;
    }

    private static Map<String, Object> card(String value, String title, String subtitle, String icon) {
        return new Map<String, Object>{ 'value' => value, 'title' => title, 'subtitle' => subtitle, 'icon' => icon };
    }
    private static Map<String, Object> cta(String value, String title, String subtitle, String ctaLabel, String icon) {
        return new Map<String, Object>{ 'value' => value, 'title' => title, 'subtitle' => subtitle, 'cta' => ctaLabel, 'icon' => icon };
    }
}