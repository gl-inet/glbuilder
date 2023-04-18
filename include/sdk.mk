
define download_sdk
sdk_target:=$(TOPDIR)/dl/sdk-$(TARGETMODEL-y)-$(TARGETVERSION-y).tar.xz
  $$(sdk_target): $(TOPDIR)/scripts/download.pl .config
	mkdir -p $$(TOPDIR)/dl
	$$< $(TOPDIR)/dl $$(notdir $$@) $$(sdk_hash) $(DOWNLOAD_URL)/sdk/$(TARGETMODEL-y)
endef

define prepare_sdk
sdk_prepare:=$(TOPDIR)/build_dir/sdk-$(TARGETMODEL-y)-$(TARGETVERSION-y)
  $$(sdk_prepare): $$(sdk_target) tmp-prepare
	mkdir -p $$(sdk_prepare)
	tar -xf $$< -C $$@ --strip-components 1 || rm -rf $$@
	#cp $$(TOPDIR)/board/$$(TARGETMODEL-y)/$$(TARGETVERSION-y)/feeds.conf.default $$(sdk_prepare)/feeds.conf.default
	echo  "$$(TARGETSDKFEEDS-y)" >$$(sdk_prepare)/feeds.conf.default
	cp $$(TOPDIR)/include/subdir.mk $$(sdk_prepare)/include/subdir.mk
	echo ""  >> $$(sdk_prepare)/feeds.conf.default
	echo "src-link glbuilder $$(TOPDIR)/customer/source"  >> $$(sdk_prepare)/feeds.conf.default
	sed -i 's/^[ \t]*//g' $$(sdk_prepare)/feeds.conf.default
	[ -d $$(sdk_prepare)/dl ] && rm -rf $$(sdk_prepare)/dl || true
	[ -L $$(sdk_prepare)/dl ] && unlink $$(sdk_prepare)/dl || true
	[ -f $$(sdk_prepare)/dl ] || ln -s $$(TOPDIR)/dl $$(sdk_prepare)/dl
endef

$(eval $(call download_sdk))
$(eval $(call prepare_sdk))


sdk/download: $(sdk_target)
sdk/prepare: $(sdk_prepare)
sdk/feeds/update: $(sdk_prepare)
	$(TOPDIR)/scripts/timestamp.pl -n $(TOPDIR)/tmp/sdk/feeds/stamp-sdk-feeds-update $(sdk_prepare)/feeds $(TOPDIR)/customer/source || \
	$(SUBMAKE) -C $(sdk_prepare) package/symlinks && \
	echo "CONFIG_AUTOREMOVE=n" >> $(sdk_prepare)/.config && \
	echo "CONFIG_AUTOREBUILD=n" >> $(sdk_prepare)/.config && \
	$(SUBMAKE) -C $(sdk_prepare) defconfig && \
	mkdir -p $(TOPDIR)/tmp/sdk/feeds/ && \
	touch $(TOPDIR)/tmp/sdk/feeds/stamp-sdk-feeds-update

sdk/compile: sdk/feeds/update tmp/.customer-package.in
	$(foreach p,$(CUSTOMERPACKAGE-y), \
		$(TOPDIR)/scripts/timestamp.pl -n $(sdk_prepare)/tmp/.glbuilder/package/feeds/glbuilder/$(p)/compiled $(CUSTOMERPATH-$(p)) || \
		$(SUBMAKE)  -C $(sdk_prepare) -j17 package/feeds/glbuilder/$(p)/compile IGNORE_ERRORS=m 2>/dev/null; \
	)

sdk_customer_target_packages:= $(sort $(foreach p,$(CUSTOMERPACKAGE-y),$(p) $(CUSTOMERDEP-$(p))))
sdk/install: sdk/compile
	mkdir -p $(TOPDIR)/bin/$(TARGETMODEL-y)-$(TARGETVERSION-y)/package
	$(warning  $(sort $(sdk_customer_target_packages)))
	$(foreach p,$(sort $(sdk_customer_target_packages)), \
		$(sdk_prepare)/staging_dir/host/bin/find $(sdk_prepare)/bin -type f -name $(p)*.ipk -exec cp -f {}  $(TOPDIR)/bin/$(TARGETMODEL-y)-$(TARGETVERSION-y)/package/ \;; \
	)

sdk/package/index: sdk/install FORCE
	(cd $(TOPDIR)/bin/$(TARGETMODEL-y)-$(TARGETVERSION-y)/package; $(sdk_prepare)/scripts/ipkg-make-index.sh . > Packages && \
		gzip -9nc Packages > Packages.gz; \
	) >/dev/null 2>/dev/null

sdk/clean:
	rm -rf $(sdk_prepare) || true
	rm -rf $(TOPDIR)/tmp/sdk || true

.PHONY: sdk/download sdk/clean  sdk/prepare sdk/compile sdk/feeds/update sdk/install sdk/package/index