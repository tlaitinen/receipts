Ext.define('Receipts.view.main.Preview', {
    alias: 'widget.receiptpreview',
    extend: 'Ext.Panel',
    layout:'fit',
    setDownloadLink: function(fileId) {
       $(this.getEl().dom).empty()
        .append('<div style="width:100%; height:100%; text-align:center;"><a target="_blank" href="backend/file/' + fileId  +'">' + __('preview.notAvailable') +  '</a></div>');
    },
    setPreviewFileId: function(fileId) { 
        if (fileId != null) {
            var div = $('<div style="width:50%; height:100%" class="easyzoom easyzoom--adjacent is-ready"><a href="backend/file/' + fileId +'"><img style="width:100%; height:100%" src="backend/file/' + fileId + '"/></a></div>');
            div.easyZoom();
            $(this.getEl().dom).empty().append(div);
        } else
            $(this.getEl().dom).empty().append($('<div style="background: #eee; width:100%; height:100%"/>'));

    }
});
