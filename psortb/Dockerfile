# PSORTb v3 — prokaryote subcellular localization predictor
# License: GPL (official Brinkman Lab image as base)
# Patches baked in to fix known runtime bugs in psortb3.pl and Perl modules
FROM --platform=linux/amd64 brinkmanlab/psortb_commandline:1.0.2

ARG PERL_BASE=/usr/local/lib/x86_64-linux-gnu/perl/5.22.1

# Bake in patched Perl modules
COPY patches/SCLBlast.pm  ${PERL_BASE}/Bio/Tools/Run/SCLBlast.pm
COPY patches/SVMLoc.pm    ${PERL_BASE}/Bio/Tools/PSort/Module/SVMLoc.pm
COPY patches/ModuleI.pm   ${PERL_BASE}/Bio/Tools/PSort/ModuleI.pm

# Bake in patched main script at a known path
COPY patches/psortb3.pl   /usr/local/bin/psortb3_patched.pl

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/run_psortb.sh /usr/local/bin/psortb3_patched.pl

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
