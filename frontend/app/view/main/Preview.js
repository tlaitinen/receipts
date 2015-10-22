Ext.define('Receipts.view.main.Preview', {
    alias: 'widget.receiptpreview',
    extend: 'Ext.Panel',
    layout:'fit',
    setPreviewFileId: function(fileId) {
        if (fileId != null)
            this.setHtml('<img style="width:100%; height:100%" src="backend/file/' + fileId + '"/>');
        else
            this.setHtml('');

    }
});
