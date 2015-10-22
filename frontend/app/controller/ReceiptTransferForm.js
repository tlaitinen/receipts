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
            'receipttransferform button[name=no]' : {
                click: function(button) {
                    button.up('window').close();
                }
            },
            'receipttransferform button[name=yes]' : {
                click: function(button) {
                    var receiptsGrid = button.up('window').sender.up('grid');
                    var selected = receiptsGrid.getSelectionModel().getSelection();
                    var form = button.up('form');
                    var processPeriodId = form.down('processperiodscombo').getValue();
                    Ext.Ajax.request({
                        url: 'backend/db/transferreceipts',
                        method: 'POST',
                        jsonData: {
                            processPeriodId: processPeriodId,
                            receiptIdList: selected.map(function (r) { return r.getId(); } )
                        },
                        success: function(request) {
                            receiptsGrid.store.reload();
                            Ext.ComponentQuery.query('receiptsgrid[processPeriodId=' + processPeriodId + ']').forEach(
                                function (g) {
                                    g.store.reload();
                                });
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
