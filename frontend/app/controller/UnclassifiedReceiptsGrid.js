Ext.define('Receipts.controller.UnclassifiedReceiptsGrid', {
    extend: 'Ext.app.Controller',
    init: function() {
        this.control({
            'unclassifiedreceiptsgrid' : {
                edit: function(editor, e) {
                    var r = e.record;
                    if (r.get('processPeriodId')) {
                        editor.grid.store.sync({
                            callback: function() {
                                editor.grid.store.suspendAutoSync();
                                editor.grid.store.remove([r], true);
                                editor.grid.store.resumeAutoSync();
                                Ext.ComponentQuery.query('receiptsgrid[processPeriodId=' + r.get('processPeriodId') + ']')
                                    .forEach(function (g) {
                                        g.store.reload();
                                    });
                            }
                        });
                    }
                }
            }
        });
   }
});
