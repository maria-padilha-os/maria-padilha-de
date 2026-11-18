#!/usr/bin/env fish

if test (count $argv) -lt 1
    echo "Usage: $(status basename) raw|compile|test|<ll_CC>"
    exit 1
end

cd (status dirname)/.. || exit 1
set -l tr_dir plugin/src/Caelestia/I18n/trs
if set -q PADILHA_TRS_DIR
    set tr_dir $PADILHA_TRS_DIR
end
set -g pot_file $tr_dir/raw.pot
mkdir -p $tr_dir

function gen -a lang
    xgettext -L $lang \
        -o $pot_file \
        --join-existing \
        --from-code=UTF-8 \
        --no-wrap \
        --add-location=file \
        --add-comments=TRANSLATORS: \
        --package-name=caelestia-shell \
        -k \
        -ktr:1 -ktrCtx:2c,1 -ktrMarked:1 \
        -ktrN:1,2 -ktrCtxN:4c,1,2 \
        -kmark:1 -kmarkCtx:2c,1 \
        -kmarkN:1,2 -kmarkCtxN:4c,1,2 \
        -ktrText:1 -ktrTextCtx:2c,1 \
        -ktrArgs:1 \
        (string match -v 'build/*' $argv[2..])
end

function compile -a po mo
    msgfmt --check-format -o $mo $po
end

function gen_manifests
    # Extension manifests are data files, not translatable source. Turn the
    # user-facing fields into ordinary Tr.tr calls so the same catalog covers
    # the extension manager and the tabs.
    set -l manifest_js (dirname $pot_file)/manifest-strings.js
    python3 scripts/manifest-strings.py $manifest_js ../extensions/*/extension.json ../share/extensions/*/extension.json
    gen JavaScript $manifest_js
    # The bridge file is temporary; do not leak its absolute path into the
    # translator template. Manifest strings are still ordinary msgids.
    perl -pi -e 's/\s*\S*manifest-strings\.js//g; s/^#:\s*$//mg' $pot_file
    rm -f $manifest_js
end

function gen_trs
    echo > $pot_file
    gen JavaScript **.qml ../extensions/**/*.qml ../share/extensions/**/*.qml
    gen JavaScript **.js
    gen C++ **.cpp **.hpp
    gen_manifests

    # Strip js format then tag qt-format, with qt-plural-format for the %n count
    perl -00 -i -pe '
        s/^#, javascript-format\n//m;
        s/, javascript-format//;

        my @fmts;
        push @fmts, "qt-format" if /%L?[1-9]/;
        push @fmts, "qt-plural-format" if /%L?n/;

        if (@fmts && !/^#,.*qt-format/m) {
            my $fmts = join ", ", @fmts;
            s/^#,/#, $fmts,/m or s/^(?=msgctxt |msgid )/#, $fmts\n/m
        }
    ' $pot_file
end

if test $argv[1] = raw
    gen_trs
    exit
end

if test $argv[1] = compile
    if test (count $argv) -lt 3
        echo "Usage: $(status basename) compile <ll_CC> <out_file>"
        exit 1
    end

    compile $tr_dir/$argv[2].po $argv[3]
    exit
end

test -f $pot_file || gen_trs

if test $argv[1] = test
    if test (count $argv) -lt 2
        echo "Usage: $(status basename) test <out_file>"
        exit 1
    end

    set -l tmp_dir (mktemp -d)
    set -l test_po $tmp_dir/test.po

    msginit --locale=en_US \
        --input=$pot_file \
        --output=$test_po \
        --no-translator 2>/dev/null
    sed -Ei 's/^msgstr(\[[0-9]+\])? "(.*)"$/msgstr\1 "[[ \2 ]]"/' $test_po
    compile $test_po $argv[2]

    rm -r $tmp_dir
    exit
end

msginit --locale=$argv[1] \
    --input=$pot_file \
    --output=$tr_dir/$argv[1].po
