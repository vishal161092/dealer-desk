/**
 * de_StartOrderCaptureAction — opens the input-method-aware capture card.
 *
 * The dealer has chosen HOW they want to give the order (photo / file / voice / manual).
 * This action creates a lightweight holder record (de_OrderCapture__c) so uploads can be
 * located server-side later, and returns a c__de_order_table card in "capture" mode. The
 * de_orderTable LWC reads inputMethod + targetRecordId + catalogue and renders the matching
 * capture UI (file uploader, voice recorder, or manual catalogue search). No static table is
 * ever shown here — the table is built only after Analyze Order runs on the captured content.
 */
global with sharing class de_StartOrderCaptureAction {

    global class Input {
        @InvocableVariable(description='How the dealer wants to give the order: a photo, a file, a voice note, or manual entry.')
        global String inputMethod;
    }

    @InvocableMethod(
        label='Start Order Capture'
        description='Creates a capture holder record and returns the input-method-aware capture card (upload / record / manual search) for the c__de_order_table lightning type.'
    )
    global static List<de_OrderTableResponse> start(List<Input> inputs) {
        String method = de_DealerDemoData.normaliseMethod(
            (inputs != null && !inputs.isEmpty()) ? inputs[0].inputMethod : null
        );

        // Holder record: the attach-target so uploaded content is findable later.
        de_OrderCapture__c holder = new de_OrderCapture__c();
        insert holder;

        Map<String, Object> payload = new Map<String, Object>{
            'mode'           => 'capture',
            'inputMethod'    => method,
            'targetRecordId' => holder.Id,
            'catalogue'      => de_DealerDemoData.catalogueList(),
            'title'          => captureTitle(method)
        };

        de_OrderTableInfo info = new de_OrderTableInfo();
        info.dataJSON = JSON.serialize(payload);

        de_OrderTableResponse resp = new de_OrderTableResponse();
        resp.result = info;
        resp.captureRecordId = holder.Id;
        resp.basketJSON = '';

        return new List<de_OrderTableResponse>{ resp };
    }

    private static String captureTitle(String method) {
        if (method == 'photo')  { return 'Upload a Photo of Your Order'; }
        if (method == 'file')   { return 'Upload Your Order File'; }
        if (method == 'voice')  { return 'Record or Attach a Voice Note'; }
        return 'Add Items from the Catalogue';
    }
}