"""Ev eşyaları kataloğu ve elle yazılmış ipucu bankası (API gerektirmeyen yerel mod için).

Her eşya, görüntü modelinin (ImageNet) bir veya birkaç sınıfına bağlanır ve iki bilmece
taşır: `simple` (7-10 ve 56-70 yaş için sade) ve `clever` (11-55 yaş için daha zekice).
Bilmeceler nesnenin adını ASLA içermez.
"""

from __future__ import annotations

from dataclasses import dataclass

from .models import AgeBand, AllHints, HintSet, ObjectProfile


@dataclass(frozen=True)
class Item:
    name: str
    labels: tuple[str, ...]
    room: str
    material: str
    simple: str
    clever: str


def _i(name: str, labels: str, room: str, material: str, simple: str, clever: str) -> Item:
    return Item(name, tuple(x.strip() for x in labels.split("|")), room, material, simple, clever)


ITEMS: list[Item] = [
    # --- salon / dekorasyon
    _i("vazo", "vase", "salon", "seramik",
       "Çiçekler bende su içer!", "Buketlerin geçici adresiyim."),
    _i("saksı", "pot", "salon", "toprak",
       "İçimde toprak, üstümde yeşil yapraklar var.", "Köklerin evi, yaprakların sahnesiyim."),
    _i("mum", "candle", "salon", "balmumu",
       "Yanınca erirsem de etrafı aydınlatırım.", "Ağlayarak ışık veririm, gözyaşlarım eriyip akar."),
    _i("abajur", "lampshade|table lamp", "salon", "kumaş",
       "Akşam olunca odayı ben aydınlatırım.", "Ampulün şapkasıyım, ışığı yumuşatırım."),
    _i("duvar saati", "wall clock|analog clock", "salon", "plastik",
       "Tik tak diye konuşurum, hiç durmam.", "Kollarım var ama hiç sarılmam; hep dönüp dururum."),
    _i("dijital saat", "digital clock|digital watch|stopwatch", "yatak odası", "plastik",
       "Rakamlarla zamanı gösteririm.", "İbrem yok ama dakikaları hiç kaçırmam."),
    _i("kum saati", "hourglass", "salon", "cam",
       "Ters çevirince içimden minik taneler akar.", "Zamanı taneler hâlinde akıtırım."),
    _i("yastık", "pillow", "salon", "kumaş",
       "Başını bana koyunca rahatlarsın.", "Rüyaların ilk durağıyım."),
    _i("battaniye", "quilt", "yatak odası", "kumaş",
       "Üşüdüğünde seni sararım.", "Kışın en sıcak sarılması benden."),
    _i("kanepe", "studio couch", "salon", "kumaş",
       "Ailece üstüme oturup televizyon izlersiniz.", "Misafirlerin ilk durağı, uykucuların gizli yatağı."),
    _i("sallanan sandalye", "rocking chair", "salon", "ahşap",
       "Üstümde otururken ileri geri sallanırsın.", "Hem otururum hem de ninni gibi sallarım."),
    _i("sandalye", "folding chair", "mutfak", "ahşap",
       "Dört bacağım var ama hiç yürümem.", "Masanın en sadık arkadaşıyım; bacaklarım var, yürüyemem."),
    _i("kitaplık", "bookcase", "salon", "ahşap",
       "Raflarımda masallar uyur.", "Binlerce sayfanın apartmanıyım."),
    _i("televizyon", "television|screen|monitor|entertainment center", "salon", "plastik",
       "Çizgi filmler bende oynar.", "Dünyayı odaya getiren pencereyim."),
    _i("kumanda", "remote control", "salon", "plastik",
       "Düğmelerime basınca kanal değişir.", "Uzaktan emir veren küçük bir komutanım."),
    _i("hoparlör", "loudspeaker", "salon", "plastik",
       "Şarkılar benden çıkar.", "Sesin büyüdüğü kapıyım."),
    _i("radyo", "radio", "salon", "plastik",
       "Düğmemi çevirince şarkılar ve haberler gelir.", "Görüntüsüz bir dünyanın sesiyim."),
    _i("kumbara", "piggy bank", "çocuk odası", "seramik",
       "Bozuk paraları karnımda saklarım.", "Bir gün kırılmak için biriktiririm."),
    _i("oyuncak ayı", "teddy", "çocuk odası", "pelüş",
       "Yumuşacığım, geceleri sana sarılırım.", "Ormanı hiç görmedim ama hep yatakta kış uykusundayım."),
    _i("yapboz", "jigsaw puzzle", "çocuk odası", "karton",
       "Parçalarımı birleştirince resim çıkar.", "Dağılırım, sabırla bir bütün olurum."),
    _i("balon", "balloon", "çocuk odası", "lastik",
       "İçim havayla dolu, iğneden korkarım.", "Nefesinle büyürüm, iğneyle biterim."),
    _i("uçurtma", "kite", "çocuk odası", "kâğıt",
       "Rüzgârlı günlerde gökyüzünde dans ederim.", "İpimi tutan oldukça bulutlara yaklaşırım."),
    _i("top", "soccer ball|basketball|tennis ball|volleyball|rugby ball|golf ball|ping-pong ball",
       "çocuk odası", "lastik",
       "Tekmeleyince yuvarlanırım!", "Köşem yok, o yüzden hep kaçarım."),
    _i("gitar", "acoustic guitar", "salon", "ahşap",
       "Tellerime dokununca şarkı söylerim.", "Altı telli bir dostum; parmaklarınla konuşurum."),
    _i("keman", "violin", "salon", "ahşap",
       "Yayla çalınınca ince ince şarkı söylerim.", "Omzunda dururum, yayla ağlarım."),
    _i("davul", "drum", "çocuk odası", "deri",
       "Bana vurdukça güm güm ses çıkarırım.", "Ritmin kalbi benim; vurdukça konuşurum."),
    _i("akordeon", "accordion", "salon", "ahşap",
       "Açıp kapadıkça nefes alıp şarkı söylerim.", "Körük gibi nefes alır, melodi veririm."),
    _i("mızıka", "harmonica", "salon", "metal",
       "Üfleyince şarkı çıkaran minik bir kutuyum.", "Cebe sığan bir orkestra; nefesinle çalarım."),
    _i("oyun kolu", "joystick", "çocuk odası", "plastik",
       "Beni oynatınca ekrandaki karakter koşar.", "Ekrandaki kahramanın direksiyonuyum."),
    _i("halı", "prayer rug|doormat", "salon", "kumaş",
       "Yerde yatarım, üstüme basarsın.", "Ayakların ilk selamlaştığı desenli zeminim."),
    _i("perde", "window shade|shower curtain|shoji", "salon", "kumaş",
       "Sabah güneşi içeri girmesin diye pencereyi örterim.", "Pencerenin göz kapağıyım."),
    _i("kalorifer", "radiator|space heater", "salon", "metal",
       "Kışın odayı ısıtırım.", "Duvardaki kış güneşiyim."),
    _i("vantilatör", "electric fan", "yatak odası", "plastik",
       "Yazın dönüp dönüp serinlik veririm.", "Kanatlarım var ama hiç uçmam."),
    _i("çan", "chime", "salon", "metal",
       "Rüzgâr esince tıngır mıngır ses çıkarırım.", "Esintinin dilini müziğe çeviririm."),
    # --- mutfak
    _i("çaydanlık", "teapot|coffeepot", "mutfak", "metal",
       "Kaynayınca içimden sıcak çay gelir.", "Sohbetlerin demlendiği yer benim."),
    _i("kupa", "coffee mug|cup", "mutfak", "seramik",
       "Sıcak içecekler bende içilir.", "Kulpumdan tut, sabahın ilk yudumu bende."),
    _i("su şişesi", "water bottle|pop bottle|beer bottle|wine bottle", "mutfak", "plastik",
       "Susayınca beni açarsın.", "Boynum uzun, içimde serinlik taşırım."),
    _i("sürahi", "water jug|pitcher", "mutfak", "cam",
       "Bardakları ben doldururum.", "Sofradaki suyun kaptanıyım."),
    _i("tava", "frying pan|wok", "mutfak", "metal",
       "Yumurtalar bende pişer.", "Kahvaltının sahnesi; ateşte dans ederim."),
    _i("tencere", "Dutch oven|Crock Pot|caldron", "mutfak", "metal",
       "Çorbalar bende pişer.", "Kapağımın altında akşam yemeği saklanır."),
    _i("kâse", "mixing bowl|soup bowl", "mutfak", "seramik",
       "Çorba ya da mısır gevreği bende durur.", "Kenarlarım yüksek, dökmeden taşırım."),
    _i("tabak", "plate", "mutfak", "porselen",
       "Yemeğini benim üstümde yersin.", "Her öğünün yuvarlak sahnesiyim."),
    _i("spatula", "spatula", "mutfak", "plastik",
       "Krepleri ben çeviririm.", "Tavadakileri ters yüz eden yardımcıyım."),
    _i("tahta kaşık", "wooden spoon|ladle", "mutfak", "ahşap",
       "Tencereyi karıştırırken beni kullanırsın.", "Çorbanın dansını ben yönetirim."),
    _i("ekmek kızartma makinesi", "toaster", "mutfak", "metal",
       "Dilimleri çıtır çıtır yaparım.", "Dilimleri ısıtır, hoop diye fırlatırım."),
    _i("mikrodalga", "microwave", "mutfak", "metal",
       "Yemeği hızlıca ısıtırım, bitince bip derim.", "Görünmez dalgalarla ısıtan bir kutuyum."),
    _i("buzdolabı", "refrigerator", "mutfak", "metal",
       "İçim hep soğuk, yiyecekleri ben saklarım.", "Kapağımı açınca ışığım yanar, içim kış."),
    _i("bulaşık makinesi", "dishwasher", "mutfak", "metal",
       "Kirli tabakları ben yıkarım.", "Sofranın ardından gelen yağmur benim içimde."),
    _i("tuzluk", "saltshaker", "mutfak", "cam",
       "Yemeğe tat katmak için beni sallarsın.", "Deniz bende minik kristaller hâlinde."),
    _i("süzgeç", "strainer", "mutfak", "metal",
       "Makarnanın suyunu ben akıtırım.", "Delik deşiğim ama işimi iyi yaparım."),
    _i("tepsi", "tray", "mutfak", "metal",
       "Bardakları üstümde taşırsın.", "Misafir çaylarının taşıyıcısıyım."),
    _i("kahve makinesi", "espresso maker", "mutfak", "metal",
       "Büyüklerin sabah içtiği köpüklü içeceği yaparım.", "Uykuyu kovan kokunun fabrikasıyım."),
    _i("ölçü kabı", "measuring cup", "mutfak", "cam",
       "Kek yaparken ne kadar süt koyacağını gösteririm.", "Tariflerin cetveliyim."),
    _i("tirbuşon", "corkscrew|can opener", "mutfak", "metal",
       "Kapakları açmaya yardım ederim.", "Kilitli şişelerin anahtarıyım."),
    # --- banyo
    _i("havlu", "bath towel|paper towel", "banyo", "pamuk",
       "Yıkandıktan sonra seni kuruturum.", "Islakları sever, kupkuru bırakırım."),
    _i("tuvalet kâğıdı", "toilet tissue", "banyo", "kâğıt",
       "Rulo rulo açılırım.", "Bitince herkesin beni aradığı rulo."),
    _i("sabunluk", "soap dispenser|lotion|sunscreen", "banyo", "plastik",
       "Bana basınca köpüklü sabun çıkar.", "Bir pompa, bir avuç köpük."),
    _i("parfüm", "perfume|hair spray", "banyo", "cam",
       "Fıs fıs sıkınca güzel kokarsın.", "Görünmem ama gittiğin her yerde hatırlanırım."),
    _i("ruj", "lipstick", "banyo", "plastik",
       "Dudakları renklendiririm.", "Bir gülümsemenin rengiyim."),
    _i("kova", "bucket", "banyo", "plastik",
       "Su taşımak için sapımdan tutarsın.", "Temizlik gününün su taşıyıcısıyım."),
    _i("küvet", "tub|washbasin", "banyo", "seramik",
       "Bana su doldurup köpük banyosu yaparsın.", "İçimde dalgasız bir deniz var."),
    _i("çamaşır makinesi", "washer", "banyo", "metal",
       "Kirli kıyafetleri döndüre döndüre yıkarım.", "Çorapların atlıkarıncasıyım."),
    _i("ilaç şişesi", "pill bottle|medicine chest", "banyo", "plastik",
       "Hasta olunca beni açarlar ama sadece büyükler!", "Şifanın küçük kutusuyum."),
    # --- yatak odası / giyim
    _i("ayakkabı", "running shoe|Loafer|clog|sandal|cowboy boot", "antre", "deri",
       "Dışarı çıkarken ayaklarına giyersin.", "Her adımında yanındayım, eşimle birlikte."),
    _i("çorap", "sock", "yatak odası", "pamuk",
       "Hep ikiz dolaşırım ama sık sık eşimi kaybederim.", "Çamaşır makinesinin en büyük gizemiyim."),
    _i("eldiven", "mitten", "antre", "yün",
       "Kışın ellerin üşümesin diye varım.", "Parmakların kışlık evi."),
    _i("hırka", "cardigan|sweatshirt|jersey", "yatak odası", "yün",
       "Serin akşamlarda üstüne giyersin.", "Düğmeli bir sıcaklık."),
    _i("güneş gözlüğü", "sunglasses|sunglass", "antre", "plastik",
       "Yazın gözlerini korumak için takarsın.", "Yaz ışığına karşı gözlerin perdesiyim."),
    _i("cüzdan", "wallet|purse", "antre", "deri",
       "Paralar ve kartlar bende durur.", "Cebindeki küçük banka."),
    _i("sırt çantası", "backpack", "çocuk odası", "kumaş",
       "Okula giderken kitaplarını taşırım.", "Omuzlarında taşıdığın ikinci dolabım."),
    _i("şemsiye", "umbrella", "antre", "kumaş",
       "Yağmur yağınca açılırım.", "Bulutlar ağlarken başının üstündeki çatıyım."),
    _i("gardırop", "wardrobe|chiffonier|chest|china cabinet", "yatak odası", "ahşap",
       "Kıyafetlerin bende asılı durur.", "Kapaklarımın ardında bütün mevsimler saklı."),
    _i("beşik", "crib|cradle|bassinet", "çocuk odası", "ahşap",
       "Bebekler bende uyur.", "Ninnilerin sallandığı küçük yatak."),
    # --- çalışma köşesi
    _i("dizüstü bilgisayar", "laptop|notebook|desktop computer", "çalışma köşesi", "metal",
       "Kapağımı açınca ekranım yanar.", "Katlanan bir pencere; arkamda bütün internet."),
    _i("klavye", "computer keyboard", "çalışma köşesi", "plastik",
       "Harflerim var ama hiç konuşmam.", "Yüz tuşlu bir piyano; şarkı değil yazı çalarım."),
    _i("fare", "mouse", "çalışma köşesi", "plastik",
       "Kuyruğum kablo, peynir yemem.", "Ekrandaki oku ben gezdiririm."),
    _i("telefon", "cellular telephone|dial telephone|iPod", "salon", "metal",
       "Uzaktaki dedenin sesini getiririm.", "Cebe sığan bir dünya."),
    _i("kalem", "ballpoint|fountain pen", "çalışma köşesi", "plastik",
       "Kâğıda resim ve yazı çizerim.", "Mürekkepten bir iz bırakırım."),
    _i("kalem kutusu", "pencil box", "çalışma köşesi", "plastik",
       "Boyaların ve uçların evi benim.", "Boyaların yatakhanesiyim."),
    _i("silgi", "rubber eraser", "çalışma köşesi", "lastik",
       "Yanlış yazınca hatanı silerim.", "Hataları affeden küçük kahraman."),
    _i("kalemtıraş", "pencil sharpener", "çalışma köşesi", "plastik",
       "Kör uçları sivriltirim.", "Uçları tıraş eden minik berber."),
    _i("dosya", "binder|file|envelope", "çalışma köşesi", "karton",
       "Kâğıtları içimde düzenli saklarım.", "Evrakların kılıfıyım."),
    _i("cetvel", "rule|slide rule", "çalışma köşesi", "plastik",
       "Düz çizgi çizmek için beni kullanırsın.", "Santim santim ölçerim."),
    _i("abaküs", "abacus", "çocuk odası", "ahşap",
       "Boncuklarımı kaydırarak sayı sayarsın.", "Hesap makinesinin dedesiyim."),
    _i("pusula", "magnetic compass", "çalışma köşesi", "metal",
       "İğnem hep kuzeyi gösterir.", "Kaybolanların en sadık rehberiyim."),
    # --- antre / temizlik
    _i("süpürge", "broom|vacuum", "antre", "plastik",
       "Yerdeki tozları ben toplarım.", "Tozların korkulu rüyasıyım."),
    _i("ütü", "iron", "yatak odası", "metal",
       "Buruşuk kıyafetleri dümdüz yaparım.", "Kırışıklıkların sıcak düşmanıyım."),
    _i("dikiş makinesi", "sewing machine", "yatak odası", "metal",
       "Kumaşları tık tık dikerim.", "İğnem hiç yorulmaz, kumaşları birleştiririm."),
    _i("sepet", "hamper|shopping basket|plastic bag|carton|crate", "antre", "hasır",
       "İçime bir şeyler koyup taşırsın.", "Örgülü bir taşıyıcıyım."),
    _i("el feneri", "torch", "antre", "plastik",
       "Elektrikler gidince ilk beni ararsın.", "Cebindeki küçük güneş."),
    _i("çakmak", "lighter|matchstick", "mutfak", "plastik",
       "Çocuklar bana dokunmaz, ben ateş yakarım!", "Bir çırpıda alev doğuran küçük ejderha."),
]

BY_NAME: dict[str, Item] = {it.name: it for it in ITEMS}

ROOM_HINTS: dict[str, tuple[str, str]] = {
    "salon": ("Herkesin toplandığı odaya bak.", "Misafirlerin ağırlandığı yerde ara."),
    "mutfak": ("Yemeklerin yapıldığı yere bak.", "Kokuların doğduğu odada ara."),
    "banyo": ("Dişlerini fırçaladığın yere bak.", "Köpüklerin ve aynaların diyarında ara."),
    "yatak odası": ("Uyuduğun odaya bir göz at.", "Rüyaların başladığı odada ara."),
    "çocuk odası": ("Oyuncakların olduğu odaya bak.", "Oyunların ve masalların odasında ara."),
    "çalışma köşesi": ("Ders çalıştığın masaya bak.", "Kalemlerin ve ekranların başında ara."),
    "antre": ("Kapının yanına bir bak.", "Eve girerken ilk geçtiğin yerde ara."),
}
DEFAULT_ROOM_HINT = ("Etrafına iyice bak, belki tam önündeyim!", "Göz önünde saklanmak en iyi saklanmaktır.")

COLOR_HINTS: dict[str, tuple[str, str]] = {
    "kırmızı": ("Domates gibi bir rengim var.", "Rengim kirazla aynı tonda."),
    "turuncu": ("Portakal gibi bir rengim var.", "Rengim gün batımından ödünç."),
    "sarı": ("Güneş gibi bir rengim var.", "Rengim limonla akraba."),
    "yeşil": ("Çimen gibi bir rengim var.", "Rengim baharın ilk yapraklarında."),
    "mavi": ("Gökyüzü gibi bir rengim var.", "Ege'nin rengini taşırım."),
    "lacivert": ("Gece gökyüzü gibi koyu bir rengim var.", "Rengim denizcilerin üniformasında."),
    "mor": ("Üzüm gibi bir rengim var.", "Rengim lavanta tarlalarından."),
    "pembe": ("Pamuk şeker gibi bir rengim var.", "Rengim çiçek açmış bir kirazda."),
    "kahverengi": ("Çikolata gibi bir rengim var.", "Rengim sonbahar topraklarında."),
    "siyah": ("Gece gibi karanlık bir rengim var.", "Rengim kömürle aynı."),
    "beyaz": ("Kar gibi bir rengim var.", "Rengim bulutlardan ödünç."),
    "gri": ("Fil gibi bir rengim var.", "Rengim yağmurlu bir gökyüzünde."),
}

COLOR_NAMES = list(COLOR_HINTS)

SIMPLE_BANDS = (AgeBand.CHILD, AgeBand.SENIOR)


def find(name: str) -> Item | None:
    return BY_NAME.get(name.strip().lower())


def _pick(band: AgeBand, pair: tuple[str, str]) -> str:
    return pair[0] if band in SIMPLE_BANDS else pair[1]


def _generic_association(profile: ObjectProfile, band: AgeBand) -> str:
    """Katalogda olmayan (elle yazılmış) bir nesne için harf ipucu."""
    name = profile.name.strip()
    letters = len(name.replace(" ", ""))
    if band in SIMPLE_BANDS:
        return f"Adım '{name[:1].upper()}' harfiyle başlıyor."
    return f"Adım {letters} harfli ve '{name[:1].upper()}' ile başlıyor."


def build_hints(profile: ObjectProfile) -> AllHints:
    item = find(profile.name)
    sets = {}
    for band in AgeBand:
        if item:
            association = _pick(band, (item.simple, item.clever))
        else:
            association = _generic_association(profile, band)
        color = COLOR_HINTS.get(profile.color)
        attribute = _pick(band, color) if color else (
            f"{profile.material.capitalize()} bir şeyim." if profile.material else "Dikkatli bakarsan beni fark edersin.")
        room = profile.likely_room or (item.room if item else "")
        location = _pick(band, ROOM_HINTS.get(room, DEFAULT_ROOM_HINT))
        sets[band.value] = HintSet(association=association, attribute=attribute, location=location)
    return AllHints(**sets)


def apply_name(profile: ObjectProfile, name: str | None, color: str | None) -> ObjectProfile:
    """Saklayanın düzelttiği ad/renk ile profili günceller."""
    update: dict = {}
    if name:
        name = name.strip().lower()[:30]
        update["name"] = name
        item = find(name)
        if item:
            update.update(category="ev eşyası", likely_room=item.room, material=item.material)
        elif name != profile.name:
            update.update(likely_room="", material="")
    if color:
        update["color"] = color.strip().lower()[:20]
    p = profile.model_copy(update=update)
    return p.model_copy(update={"summary": f"{p.color} {p.name}".strip()})
