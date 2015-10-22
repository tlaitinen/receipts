Ext.define('Receipts.controller.ReceiptPreview', {
    extend: 'Ext.app.Controller',
    init: function() {
        function selectionChange(selectionModel, selected, eOpts) {
            Ext.ComponentQuery.query('receiptpreview[processPeriodId=' + selectionModel.view.ownerCt.processPeriodId  + ']').forEach(function(preview) {
                if (selected.length == 1) {
                    preview.setPreviewFileId(selected[0].get('previewFileId'));
                } else {
                    preview.setPreviewFileId(null);
                }
            });
        }

        this.control({
            'receiptsgrid' : {
                selectionchange: selectionChange
            },
            'unclassifiedreceiptsgrid' : {
                selectionchange: selectionChange
            }
        });
   }
});
