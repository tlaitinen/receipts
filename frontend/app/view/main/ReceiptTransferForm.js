Ext.define('Receipts.view.main.ReceiptTransferForm' ,{
    extend: 'Ext.form.Panel',
    alias: 'widget.receipttransferform',
    bodyPadding: 5,

    buttons: [
        { text : __('receipttransferform.yes'), name : 'yes', disabled:true },
        { text : __('receipttransferform.no'), name : 'no'  }
    ],
    items: [
        {
            xtype:'processperiodscombo',
            fieldLabel:'Kirjanpitojakso',
            name:'processPeriodId',
            forceSelection:true,
            flex:1
        }
    ]
});
