Ext.define('Receipts.view.main.Preview', {
    alias: 'widget.receiptpreview',
    extend: 'Ext.Panel',
    layout:'fit',
    setPreviewFileId: function(fileId) { 
        if (fileId != null) {
            var div = $('<div style="width:50%; height:100%" class="easyzoom easyzoom--adjacent is-ready"><a href="backend/file/' + fileId +'"><img style="width:100%; height:100%" src="backend/file/' + fileId + '"/></a></div>');
            div.easyZoom();
            $(this.getEl().dom).empty().append(div);
        } else
            this.setHtml('<div style="background: #eee; width:100%; height:100%"/>');

    }
});
