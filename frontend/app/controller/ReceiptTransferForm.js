Ext.define('Receipts.controller.ReceiptTransferForm', {
    extend: 'Ext.app.Controller',
    views: ['main.ReceiptTransferForm'],

    init: function() {
        this.control({
            'receipttransferform processperiodscombo' : {
                change: function(combo) {
                    if (combo.getValue()) {
                        combo.up('form').down('button[name=yes]').enable();
                    }
                }
            },
            'receipttransferform button[name=yes]' : {
                click: function(button) {
                    var receiptsGrid = Ext.ComponentQuery.query('panel[name=receipts] receiptsgrid')[0];
                    var selected = receiptsGrid.getSelectionModel().getSelection();
                    var form = button.up('form');
                    Ext.Ajax.request({
                        url: 'backend/db/transferreceipts',
                        method: 'POST',
                        jsonData: {
                            processPeriodId: form.down('processperiodscombo').getValue(),
                            receiptIdList: selected.map(function (r) { return r.getId(); } )
                        },
                        success: function(request) {
                            Ext.getStore('receipts').reload();
                        },
                        failure: function(request) {
                            Ext.Msg.alert(__('receipttransferform.errortitle'), __('receipttransferform.errormessage'));
                        }
                    });
                    form.up('window').close();
                }
            }
        });
    }

});
