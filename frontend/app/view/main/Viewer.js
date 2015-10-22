Ext.define('Receipts.view.main.Viewer', {

    alias: 'widget.receiptsviewer',
    extend: 'Ext.tab.Panel',
    requires: [
        'Receipts.view.main.Preview'
    ],
    initComponent: function(c) {
        function capitalize(string) {
                return string.charAt(0).toUpperCase() + string.slice(1);
        }

        var viewer = this;
        Receipts.GlobalState.on('login', function(process) {
            var years = [];
            var pp = Ext.getStore('processperiods');
            var periods = [];

            for (var i = 0; i < pp.count(); i++) {
                var year = pp.getAt(i).get('firstDay').getFullYear();
                if (years.indexOf(year) == -1)
                    years.push(year);
                periods.push(pp.getAt(i));
            }
            periods.sort(function(a,b) {
                if (a.get('firstDay') < b.get('firstDay'))
                    return -1
                else 
                    return 1;
            });
            years.sort();
            var yearTab = null;
            years.forEach(function (year) {
                var tabs = _.map(_.filter(periods, function (p) { return p.get('firstDay').getFullYear() == year; }),
                        function(p) {
                            return {
                                xtype: 'panel',
                                title: capitalize(moment(p.get('firstDay')).format('MMMM')),
                                layout: {
                                    type:'vbox',
                                    align:'stretch'
                                },
                                items: [
                                    { 
                                        xtype: 'panel',
                                        layout: {
                                            type:'hbox',
                                            align:'stretch'
                                        },
                                        items: [
                                            {
                                                xtype:'receiptsgrid',
                                                processPeriodId: p.getId(),
                                                flex:1,
                                                filters: [
                                                    {
                                                        field: 'processPeriodId',
                                                        value: ''+p.getId()
                                                    }
                                                ]
                                            },
                                            {
                                                xtype:'receiptpreview',
                                                processPeriodId:p.getId(),
                                                flex:1
                                            }
                                        ],
                                        flex:3

                                    },
                                    { 
                                        xtype: 'receiptupload', 
                                        flex:1,
                                        processPeriodId: p.getId(),
                                        title: __('upload.title'),
                                        autoscroll:true
                                    }
                                ]
                            }
                        })
                yearTab = viewer.add({
                    xtype:'tabpanel',
                    title:''+year,
                    activeTab: tabs.length - 1,
                    items: tabs
                });
            });

            var unclassified = viewer.add({
                xtype: 'panel',
                title: __('receipts.unclassified'),
                layout: {
                    type:'hbox',
                    align:'stretch'
                },
                items: [
                    {
                        xtype:'unclassifiedreceiptsgrid',
                        processPeriodId:null,
                        flex:1
                    },
                    {
                        xtype:'receiptpreview',
                        processPeriodId:null,
                        flex:1
                    }
                ]
            });

            if (yearTab)
                viewer.setActiveTab(yearTab);
            else
                viewer.setActiveTab(unclassified);
        });

        this.callParent(arguments);
    }
});
