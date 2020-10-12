Try installing the kernel without deb pkg.

Why: make deb-pkg is quite slow, doesn't seem to be able to use `-j $(nproc)`,
fails without completely cleaning the tree first.

It's not clear how to install perf without `make install`.

It's not clear though how to install everything in place.  There are
`INSTALL_PATH`, `INSTALL_MOD_PATH`, `INSTALL_HDR_PATH`, and `INSTALL_DTBS_PATH`
variables that probably should be set.  But probably worth doing it in a chroot
just in case, to avoid overwriting host machine kernel.

Will probably need to run update-initramfs afterwards inside the chroot.

Also see `make help`, Documentation/kbuild/kbuild.txt, and Documentation/kbuild/makefiles.txt.
