"""Writes the fictional companies' logos as SVG tiles to assets/images/logos/.

Run from the project root: python tool/make_company_logos.py
Each logo is a 96×96 square (the app rounds the corners), with a bold mark that still reads at 40 px.
Add a company here and to `companyLogos` in lib/widgets/career_widgets.dart to give it a logo.
"""
from pathlib import Path

LOGOS = {
    # PT Sinar Mandiri Abadi (finance, admin, HR): a rising sun over a horizon
    'sinar-mandiri-abadi': '''<rect width="96" height="96" fill="#1E4E8C"/>
<g stroke="#FFC845" stroke-width="5" stroke-linecap="round">
<line x1="48" y1="18" x2="48" y2="27"/><line x1="25" y1="28" x2="31" y2="34"/><line x1="71" y1="28" x2="65" y2="34"/>
<line x1="16" y1="50" x2="24" y2="50"/><line x1="80" y1="50" x2="72" y2="50"/></g>
<path d="M28 60a20 20 0 0 1 40 0z" fill="#FFC845"/>
<rect x="18" y="64" width="60" height="6" rx="3" fill="#FFFFFF"/>
<rect x="28" y="74" width="40" height="5" rx="2.5" fill="#FFFFFF" opacity=".55"/>''',
    # Kopi Lereng Slamet (coffee UMKM): a coffee bean on the slope of Mount Slamet
    'kopi-lereng-slamet': '''<rect width="96" height="96" fill="#5B3420"/>
<path d="M30 84 L64 28 L98 84 Z" fill="#8C5A3A"/>
<path d="M64 28 L72 41 L66 44 L60 39 L56 41 Z" fill="#F3E3CF"/>
<g transform="rotate(-30 38 58)">
<ellipse cx="38" cy="58" rx="16" ry="23" fill="#F3E3CF"/>
<path d="M38 36 C30 50 46 66 38 80" stroke="#5B3420" stroke-width="4.5" fill="none" stroke-linecap="round"/></g>''',
    # Tani Digital Nusantara (agritech): a leaf drawn as a circuit
    'tani-digital-nusantara': '''<rect width="96" height="96" fill="#2E7D4F"/>
<path d="M22 74 C20 42 44 22 74 22 C74 52 56 74 22 74 Z" fill="#B8E986"/>
<path d="M26 70 L64 32" stroke="#2E7D4F" stroke-width="4" stroke-linecap="round"/>
<path d="M40 56 V46 M50 46 H58 M46 50 V40" stroke="#2E7D4F" stroke-width="3.5" stroke-linecap="round"/>
<circle cx="40" cy="44" r="3.5" fill="#2E7D4F"/><circle cx="60" cy="46" r="3.5" fill="#2E7D4F"/><circle cx="46" cy="38" r="3.5" fill="#2E7D4F"/>''',
    # BPR Artha Sejahtera (rural bank): a gold coin under a bank pediment
    'bpr-artha-sejahtera': '''<rect width="96" height="96" fill="#0D3B66"/>
<path d="M48 14 L82 32 L14 32 Z" fill="#E9B949"/>
<g fill="#FFFFFF"><rect x="20" y="38" width="9" height="28" rx="2"/><rect x="67" y="38" width="9" height="28" rx="2"/></g>
<circle cx="48" cy="52" r="14" fill="#E9B949"/>
<path d="M43 44 V60 M43 44 H50 A4 4 0 0 1 50 52 H43 M43 52 H51 A4 4 0 0 1 51 60 H43" fill="none" stroke="#0D3B66" stroke-width="3" stroke-linejoin="round"/>
<rect x="14" y="70" width="68" height="8" rx="2" fill="#FFFFFF"/>''',
    # KAP Wijaya & Rekan (public accountants): a ledger with a gold check seal
    'kap-wijaya-rekan': '''<rect width="96" height="96" fill="#2F3A45"/>
<rect x="20" y="16" width="52" height="62" rx="6" fill="#F4F1EA"/>
<g stroke="#2F3A45" stroke-width="3.5" stroke-linecap="round"><line x1="30" y1="30" x2="62" y2="30"/><line x1="30" y1="40" x2="62" y2="40"/><line x1="30" y1="50" x2="48" y2="50"/></g>
<circle cx="64" cy="66" r="16" fill="#C9A227"/>
<path d="M56 66 L62 72 L72 60" stroke="#FFFFFF" stroke-width="5" fill="none" stroke-linecap="round" stroke-linejoin="round"/>''',
    # CV Berkah Logistik (warehouse logistics): a parcel box moving forward
    'berkah-logistik': '''<rect width="96" height="96" fill="#E8590C"/>
<path d="M44 18 L70 31 L70 61 L44 74 L18 61 L18 31 Z" fill="#FFF4E6"/>
<path d="M18 31 L44 44 L70 31 M44 44 V74" stroke="#E8590C" stroke-width="3.5" fill="none" stroke-linejoin="round"/>
<path d="M31 25 L57 38" stroke="#E8590C" stroke-width="3.5"/>
<path d="M58 80 H84 M76 72 L84 80 L76 88" stroke="#FFFFFF" stroke-width="5" fill="none" stroke-linecap="round" stroke-linejoin="round"/>''',
    # PT Banyumas Net Media (internet provider): signal arcs over a mast
    'banyumas-net-media': '''<rect width="96" height="96" fill="#0B7A8A"/>
<g fill="none" stroke="#FFFFFF" stroke-width="5.5" stroke-linecap="round">
<path d="M22 40 A36 36 0 0 1 74 40"/><path d="M32 50 A22 22 0 0 1 64 50"/></g>
<circle cx="48" cy="58" r="6.5" fill="#7FE3D7"/>
<path d="M48 64 L37 84 M48 64 L59 84 M42 75 H54" stroke="#7FE3D7" stroke-width="4.5" stroke-linecap="round"/>''',
    # CV Mitra Komputindo (computer services): a monitor showing a chip
    'mitra-komputindo': '''<rect width="96" height="96" fill="#3446A6"/>
<rect x="14" y="20" width="68" height="44" rx="6" fill="#E3E8FF"/>
<rect x="20" y="26" width="56" height="32" rx="3" fill="#3446A6"/>
<rect x="39" y="33" width="18" height="18" rx="3" fill="#8FA2FF"/>
<g stroke="#8FA2FF" stroke-width="3" stroke-linecap="round"><line x1="44" y1="29" x2="44" y2="33"/><line x1="52" y1="29" x2="52" y2="33"/><line x1="44" y1="51" x2="44" y2="55"/><line x1="52" y1="51" x2="52" y2="55"/></g>
<path d="M40 64 L36 78 H60 L56 64 Z" fill="#E3E8FF"/>''',
    # Toko Swalayan Mitra (supermarket): a shopping basket
    'toko-swalayan-mitra': '''<rect width="96" height="96" fill="#C92A2A"/>
<path d="M30 42 L40 20 M66 42 L56 20" stroke="#FFFFFF" stroke-width="5.5" stroke-linecap="round"/>
<path d="M16 42 H80 L72 78 H24 Z" fill="#FFFFFF" stroke="#FFFFFF" stroke-width="2" stroke-linejoin="round"/>
<g stroke="#C92A2A" stroke-width="4" stroke-linecap="round"><line x1="35" y1="52" x2="37" y2="69"/><line x1="48" y1="52" x2="48" y2="69"/><line x1="61" y1="52" x2="59" y2="69"/></g>''',
    # PT Graha Niaga (trading house): stacked buildings
    'graha-niaga': '''<rect width="96" height="96" fill="#5B3FA8"/>
<rect x="16" y="44" width="28" height="36" rx="3" fill="#D8CCFF"/>
<rect x="38" y="18" width="24" height="62" rx="3" fill="#FFFFFF"/>
<rect x="58" y="34" width="22" height="46" rx="3" fill="#A992F2"/>
<g fill="#5B3FA8"><rect x="44" y="26" width="4" height="7"/><rect x="52" y="26" width="4" height="7"/><rect x="44" y="39" width="4" height="7"/><rect x="52" y="39" width="4" height="7"/><rect x="44" y="52" width="4" height="7"/><rect x="52" y="52" width="4" height="7"/></g>''',
    # Batik Lumbon Banyumas (batik): a kawung motif
    'batik-lumbon-banyumas': '''<rect width="96" height="96" fill="#7A2340"/>
<g fill="#F6D7A7"><ellipse cx="48" cy="29" rx="11" ry="17"/><ellipse cx="48" cy="67" rx="11" ry="17"/><ellipse cx="29" cy="48" rx="17" ry="11"/><ellipse cx="67" cy="48" rx="17" ry="11"/></g>
<circle cx="48" cy="48" r="6" fill="#7A2340"/><circle cx="48" cy="48" r="2.5" fill="#F6D7A7"/>
<g fill="#7A2340"><circle cx="48" cy="27" r="3.2"/><circle cx="48" cy="69" r="3.2"/><circle cx="27" cy="48" r="3.2"/><circle cx="69" cy="48" r="3.2"/></g>''',
    # PT Agro Serayu Lestari (plantation by the Serayu river): a sprout over river waves
    'agro-serayu-lestari': '''<rect width="96" height="96" fill="#4C7A2A"/>
<path d="M48 58 V34" stroke="#F0F7D4" stroke-width="5" stroke-linecap="round"/>
<path d="M48 40 C34 40 26 30 26 18 C42 18 48 28 48 40 Z" fill="#F0F7D4"/>
<path d="M48 36 C62 36 70 28 70 16 C56 16 48 24 48 36 Z" fill="#C5E86C"/>
<path d="M12 66 C22 58 34 58 44 66 C54 74 66 74 84 64" stroke="#8FD3F4" stroke-width="6" fill="none" stroke-linecap="round"/>
<path d="M12 80 C22 72 34 72 44 80 C54 88 66 88 84 78" stroke="#8FD3F4" stroke-width="6" fill="none" stroke-linecap="round" opacity=".6"/>''',
    # Lapak Kriya Nusantara (craft marketplace): a market stall awning over a woven tile
    'lapak-kriya-nusantara': '''<rect width="96" height="96" fill="#B5532A"/>
<path d="M16 18 H80 L84 34 H12 Z" fill="#FFE8D2"/>
<path d="M12 34 a9 7 0 0 0 18 0 a9 7 0 0 0 18 0 a9 7 0 0 0 18 0 a9 7 0 0 0 18 0 Z" fill="#FFE8D2"/>
<g stroke="#B5532A" stroke-width="3"><line x1="32" y1="18" x2="30" y2="34"/><line x1="48" y1="18" x2="48" y2="34"/><line x1="64" y1="18" x2="66" y2="34"/></g>
<rect x="26" y="50" width="44" height="30" rx="3" fill="#FFE8D2"/>
<g stroke="#B5532A" stroke-width="4"><line x1="26" y1="60" x2="70" y2="60"/><line x1="26" y1="70" x2="70" y2="70"/></g>
<g stroke="#B5532A" stroke-width="4" opacity=".55"><line x1="40" y1="50" x2="40" y2="80"/><line x1="56" y1="50" x2="56" y2="80"/></g>''',
    # PT Serayu Logistik Mandiri (logistics): a truck on a river road
    'serayu-logistik-mandiri': '''<rect width="96" height="96" fill="#1659A8"/>
<rect x="12" y="26" width="42" height="30" rx="3" fill="#FFFFFF"/>
<path d="M54 34 H69 L82 47 V56 H54 Z" fill="#CFE5FF"/>
<rect x="60" y="38" width="9" height="8" rx="1.5" fill="#1659A8"/>
<g fill="#1659A8" stroke="#FFFFFF" stroke-width="4"><circle cx="27" cy="58" r="7.5"/><circle cx="68" cy="58" r="7.5"/></g>
<path d="M10 78 C22 70 36 70 48 78 C60 86 74 86 86 78" stroke="#7FC8FF" stroke-width="5.5" fill="none" stroke-linecap="round"/>''',
}

if __name__ == '__main__':
    out = Path('assets/images/logos')
    out.mkdir(parents=True, exist_ok=True)
    for name, body in LOGOS.items():
        (out / f'{name}.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96">\n{body}\n</svg>\n', encoding='utf-8')
    # A contact sheet for reviewing all logos side by side (not bundled with the app). SVGs are inlined so the page
    # renders on its own, at the card size (40 px) and the detail size (96 px).
    def tile(n, size, radius):
        svg = (out / f'{n}.svg').read_text(encoding='utf-8').replace('<svg ', f'<svg width="{size}" height="{size}" style="border-radius:{radius}px" ', 1)
        return svg
    tiles = ''.join(f'<figure>{tile(n, 96, 29)}{tile(n, 40, 12)}<figcaption>{n}</figcaption></figure>' for n in LOGOS)
    Path('build').mkdir(exist_ok=True)
    Path('build/logos-preview.html').write_text(
        '<!doctype html><meta charset="utf-8"><title>Logo perusahaan</title><style>'
        'body{font-family:sans-serif;background:#F6F7F4;display:flex;flex-wrap:wrap;gap:16px;padding:16px}'
        'figure{margin:0;background:#fff;border:1px solid #DDE2DC;border-radius:16px;padding:12px;width:150px;text-align:center}'
        'svg{margin:4px;vertical-align:bottom}figcaption{font-size:12px;color:#55606A}'
        f'</style>{tiles}',
        encoding='utf-8',
    )
    print(f'{len(LOGOS)} logo ditulis ke {out}; pratinjau: build/logos-preview.html')
