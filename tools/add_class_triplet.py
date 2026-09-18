"""
Generic: add a class triplet to every SWF XML whose Add_SWF block compiles a
given driver source, and register the new .as path in those blocks.

usage: python addclass2.py <FullClassName> <as-path-in-block> <driver.as>
   e.g. python addclass2.py skyui.components.SubCategoryBar \
            Common/skyui/components/SubCategoryBar.as InventoryLists.as
Idempotent.
"""
import re
import os
import sys

CLASS = sys.argv[1]
ASPATH = sys.argv[2]
DRIVER = sys.argv[3]

ROOT = "source"
CMAKE = os.path.join(ROOT, "swfsources.cmake")
NEWNAME = "__Packages." + CLASS
DONOR = "__Packages.skyui.filter.ItemTypeFilter"

cm = open(CMAKE, encoding="utf-8").read()
blocks = re.split(r"(?=Add_SWF\()", cm)

targets = []
for b in blocks:
    m = re.match(r"Add_SWF\(\s*(\w+)\s*\n\s*(\S+)\s*\n\s*(\S+)", b)
    if m and DRIVER in b:
        targets.append((m.group(1), m.group(3)))
print("blocks compiling %s: %d" % (DRIVER, len(targets)))

for name, xmlrel in targets:
    path = os.path.join(ROOT, "swf", xmlrel)
    if not os.path.exists(path):
        print("  SKIP %-22s no xml" % name)
        continue
    s = open(path, encoding="utf-8", errors="surrogateescape").read()
    if NEWNAME in s:
        print("  ok   %-22s already present" % name)
        continue

    ids = [int(x) for x in re.findall(r'spriteId="(\d+)"', s)]
    ids += [int(x) for x in re.findall(r'characterId="(\d+)"', s)]
    newid = str(max(ids) + 1)

    i_name = s.find(DONOR)
    if i_name < 0:
        print("  FAIL %-22s donor absent" % name)
        continue
    i_exp = s.rfind('<item type="ExportAssetsTag"', 0, i_name)
    donorid = re.search(r"<item>(\d+)</item>", s[i_exp:i_name]).group(1)

    m_sprite = re.search(
        r'[ \t]*<item type="DefineSpriteTag"[^>]*spriteId="%s">\s*<subTags/>\s*</item>' % donorid, s)
    m_doinit = re.compile(
        r'[ \t]*<item type="DoInitActionTag"[^>]*spriteId="%s"\s*/>' % donorid).search(s, i_name)
    if not (m_sprite and m_doinit):
        print("  FAIL %-22s cannot bracket donor %s" % (name, donorid))
        continue

    blk = s[m_sprite.start():m_doinit.end()]
    nb = blk.replace('spriteId="%s"' % donorid, 'spriteId="%s"' % newid)
    nb = nb.replace(DONOR, NEWNAME)
    nb = nb.replace("<item>%s</item>" % donorid, "<item>%s</item>" % newid)
    s = s[:m_doinit.end()] + "\n" + nb + s[m_doinit.end():]
    open(path, "w", encoding="utf-8", errors="surrogateescape").write(s)
    print("  ADD  %-22s %s -> spriteId %s" % (name, xmlrel, newid))

out = []
added = 0
anchor = "    Common/skyui/defines/Input.as\n"
for b in blocks:
    m = re.match(r"Add_SWF\(\s*(\w+)", b)
    if m and DRIVER in b and ASPATH not in b:
        if anchor in b:
            b = b.replace(anchor, anchor + "    " + ASPATH + "\n", 1)
            added += 1
        else:
            print("  WARN %-22s no anchor line to register after" % m.group(1))
    out.append(b)
open(CMAKE, "w", encoding="utf-8").write("".join(out))
print("registered %s in %d blocks" % (ASPATH, added))
