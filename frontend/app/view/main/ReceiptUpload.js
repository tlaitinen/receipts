Ext.define('Receipts.view.main.ReceiptUpload', {

    alias: 'widget.receiptupload',
    extend: 'Ext.Panel',

     html: '<div name="receiptuploadDiv" class="fileUpload"><input name="receiptupload" type="file" name="files" multiple value="' + __('upload.button') + '"/>' + __('upload.button') + '</div><div name="progress"></div>',

    uploadHandler: function(view, e) {
        e.preventDefault();
        function parseInfo(name) {
            var delims = [' ', '_', '-'];
            var r = {
                name: '',
                amount:0
            };
            delims.forEach(function(delim) {
                var parts = name.split(delim),
                    indexPart = undefined;
                console.log(parts);
                for (var i = 0; i < parts.length; i++) {
                    var part = parts[i],
                        xs = part.split(",");
                    if (xs.length == 2) {
                        try {
                            var amount = parseFloat(part.replace(",", "."));
                            if (amount) {
                                r.amount = amount;
                                indexPart = i;
                            }
                        } catch (e) {
                            console.log(e);
                        }
                    }
                }
                if (indexPart != undefined) {
                    parts.splice(indexPart, 1);
                    r.name = parts.join(" ");
                }
            });
            if (!r.name) {
                r.name = name;
            }
            r.name  = r.name.replace(/\.[^/.]+$/, "");
            return r;
        }

        function createProgressBar(file) {

            var now = new Date().getTime();
            var ctrl = {
                label: 'uploadlabel-' + now,
                bar: 'upload-' + now,
                update: function(p) {
                    this.progress.updateProgress(p/100.0, __('upload.uploading'));

                },
                done: function(s, msg) {
                    this.progress.updateProgress(1, msg);
                    var ctrl = this;
                    setTimeout(function() { 
                        $(view.getEl().dom).find('[name=' + ctrl.label+']').remove();
                            }, 5000);
                }
            };
            var progress = $(view.getEl().dom).find("div[name=progress]");
            var bar = $('<div>');
            $('<span>')
                .attr("name", ctrl.label)
                .html(bar)
                .appendTo(progress);

            ctrl.progress = Ext.create('Ext.ProgressBar', {
                  renderTo: bar[0],
                  width: '100%'
            });
            
            return ctrl;
        }
        function FileUpload(file) {
            this.ctrl = createProgressBar(file);
            var xhr = new XMLHttpRequest();
            var self = this;
            xhr.upload.addEventListener("progress", function(e) {
                    if (e.lengthComputable) {
                        var percentage = Math.round((e.loaded * 100) / e.total);
                        self.ctrl.update(percentage);
                    }        
                }, false);
            xhr.upload.addEventListener("load", function(e) {
                self.ctrl.update(100);        
                    }, false);
            xhr.open("POST", "backend/upload-files", true);
            var fd = new FormData();
            if (["application/pdf", "image/png", "image/jpeg", "image/gif", "image/bmp", "image/tiff"].indexOf(file.type) > -1) {
                fd.append('convert', 'pdf');
                fd.append('preview', 'jpeg');
            }
            fd.append('file', file);
            xhr.onreadystatechange = function() {
                if (xhr.readyState == 4) {
                    try {
                        var r = JSON.parse(xhr.responseText);
                        self.ctrl.done(xhr.status, file.name + ' ' + r.result);
                        var info = parseInfo(file.name);

                        var receipt = Ext.create('Receipts.model.receipts',
                            {
                                name: info.name,
                                amount: info.amount,
                                fileId: r.fileId,
                                previewFileId: r.previewFileId,
                                processPeriodId: view.processPeriodId,
                                fileName: file.name,
                                insertionTime: (new Date()).toJSON()
                            });
                        console.log(view.processPeriodId);
                        console.log(receipt);
                        receipt.save({
                            success: function(rec, op) {
                                var r = JSON.parse(op.getResponse().responseText);
                                receipt.setId(r.id);
                                Ext.ComponentQuery.query('receiptsgrid[processPeriodId=' + view.processPeriodId + ']')
                                    .forEach(function (g) {
                                        g.store.add(receipt);
                                    });
                            }
                        });

                        

                    } catch (e) {
                        console.log(e);
                    }
                }
            }
            xhr.send(fd);
        }
        var files = e.target.files || e.dataTransfer.files;
        for (var i = 0, f; f = files[i]; i++) {
            new FileUpload(f);
        }        

    },

    onRender: function(ct) {
        this.callParent(arguments);
        var html = $(this.getEl().dom);
        var input = html.find("input");
        var view = this;
        input[0].addEventListener("change", function(e) { view.uploadHandler(view, e); }, false);
        var div =html.find("div[name=receiptuploadDiv]")[0];
        div.addEventListener('drop', function (e) { view.uploadHandler(view, e); }, false);
        div.addEventListener('dragover', function (e) { e.preventDefault(); $(div).addClass('hover'); return false; }, false);
        div.addEventListener('dragleave', function (e) { e.preventDefault();  $(div).removeClass('hover'); return false; }, false);
    }

});
