"""Görüntü AI katmanı.

`ClaudeVision` gerçek Claude API'sini kullanır. `FakeVision` ağ ve API anahtarı
olmadan geliştirme/test yapmak için deterministik cevaplar döner.
Hangisinin kullanılacağı `AI_MODE` ortam değişkeniyle seçilir (claude | fake).
"""

from __future__ import annotations

import logging
import os
from typing import Protocol, TypeVar

import anthropic
from pydantic import BaseModel

from .models import AllHints, HintSet, MatchVerdict, ObjectProfile

log = logging.getLogger(__name__)

MODEL = os.environ.get("CLAUDE_MODEL", "claude-opus-5-5")

T = TypeVar("T", bound=BaseModel)


class AIError(RuntimeError):
    """AI isteği tamamlanamadı (ağ, oran sınırı, ret vb.)."""


class Vision(Protocol):
    async def identify(self, images_b64: list[str]) -> ObjectProfile: ...

    async def make_hints(self, profile: ObjectProfile) -> AllHints: ...

    async def verify(
        self, profile: ObjectProfile, reference_b64: list[str], candidate_b64: str
    ) -> MatchVerdict: ...


def _image_block(b64: str) -> dict:
    return {
        "type": "image",
        "source": {"type": "base64", "media_type": "image/jpeg", "data": b64},
    }


IDENTIFY_SYSTEM = """Sen ev içinde oynanan bir saklambaç/bulmaca oyununun hakemisin.
Saklayan oyuncu bir nesnenin birkaç fotoğrafını çekti. Görevin nesneyi tanımlamak.
- Fotoğraflarda tek, net, evde bulunan fiziksel bir nesne yoksa valid=false yap.
- İnsan, evcil hayvan, ekran içeriği, belge veya kişisel bilgi içeren nesneleri kabul etme (valid=false).
- Tüm metinler Türkçe olsun.
- distinctive_features: aynı türden başka bir nesneyle karıştırılmaması için görsel ayırt edici
  özellikler (desen, çizik, etiket, şekil detayı, boyut ipucu)."""

HINTS_SYSTEM = """Ev içinde oynanan bir bulma oyunu için ipucu yazarısın.
Ebeler gizli nesneyi arıyor. Her yaş grubu için 3 ipucu yaz:
- association: nesnenin ADINI ve RENGİNİ asla söyleme; ne işe yaradığını veya neyi çağrıştırdığını
  bilmece gibi anlat.
- attribute: rengi veya malzemeyi doğrudan değil, çağrıştırarak ima et ("gökyüzünün rengi" gibi).
  Nesnenin adını söyleme.
- location: nerede olabileceğini ima et, nesnenin adını söyleme.
Yaş grupları: child=7-10 (çok sade, sevimli, kısa cümle), teen=11-15 (eğlenceli),
adult=16-55 (zekice, kelime oyunu olabilir), senior=56-70 (sıcak, net, kültürel çağrışım).
Her ipucu en fazla 20 kelime, Türkçe."""

VERIFY_SYSTEM = """Ev içinde oynanan bir bulma oyununun hakemisin.
İlk görüntüler saklanan nesnenin referans fotoğraflarıdır. Son görüntü ebenin taradığı adaydır.
Aday, referanstaki AYNI fiziksel nesne mi? Sadece aynı tür ya da aynı renk olması yetmez;
ayırt edici özelliklere bak. Açı, ışık ve mesafe farklı olabilir. Emin değilsen same_object=false.
feedback Türkçe, kısa ve cesaretlendirici olsun; eşleşmiyorsa doğru nesneyi ele verme."""


class ClaudeVision:
    def __init__(self, client: anthropic.AsyncAnthropic | None = None) -> None:
        self.client = client or anthropic.AsyncAnthropic()

    async def _ask(
        self, schema: type[T], system: str, content: list[dict], effort: str, max_tokens: int = 8000
    ) -> T:
        try:
            response = await self.client.beta.messages.parse(
                model=MODEL,
                max_tokens=max_tokens,
                system=system,
                messages=[{"role": "user", "content": content}],
                output_format=schema,
                output_config={"effort": effort},
                # Bir güvenlik sınıflandırıcısı reddederse sunucu tarafında önerilen
                # yedek modele düşer.
                betas=["server-side-fallback-2026-07-01"],
                fallbacks="default",
            )
        except anthropic.RateLimitError as e:
            raise AIError("AI şu an yoğun, birkaç saniye sonra tekrar dene.") from e
        except anthropic.APIConnectionError as e:
            raise AIError("AI servisine bağlanılamadı.") from e
        except anthropic.APIStatusError as e:
            log.error("Claude API hatası %s: %s", e.status_code, e.message)
            raise AIError("AI isteği başarısız oldu.") from e

        if response.stop_reason == "refusal":
            raise AIError("AI bu görüntüyü değerlendirmeyi reddetti.")
        if response.parsed_output is None:
            raise AIError("AI cevabı okunamadı.")
        return response.parsed_output

    async def identify(self, images_b64: list[str]) -> ObjectProfile:
        content = [_image_block(b) for b in images_b64]
        content.append({"type": "text", "text": "Bu nesneyi tanımla."})
        return await self._ask(ObjectProfile, IDENTIFY_SYSTEM, content, effort="medium")

    async def make_hints(self, profile: ObjectProfile) -> AllHints:
        text = (
            "Gizli nesne profili (JSON):\n"
            + profile.model_dump_json(indent=2)
            + "\n\nDört yaş grubu için ipuçlarını yaz."
        )
        return await self._ask(
            AllHints, HINTS_SYSTEM, [{"type": "text", "text": text}], effort="medium"
        )

    async def verify(
        self, profile: ObjectProfile, reference_b64: list[str], candidate_b64: str
    ) -> MatchVerdict:
        content: list[dict] = [{"type": "text", "text": "Referans fotoğraflar:"}]
        content += [_image_block(b) for b in reference_b64]
        content.append(
            {
                "type": "text",
                "text": "Referans nesnenin profili: "
                + profile.model_dump_json()
                + "\n\nEbenin taradığı aday görüntü:",
            }
        )
        content.append(_image_block(candidate_b64))
        # Hız önemli: ebe sonucu bekliyor.
        return await self._ask(MatchVerdict, VERIFY_SYSTEM, content, effort="low", max_tokens=4000)


class FakeVision:
    """Geliştirme ve test için. Görüntü içeriğine bakmaz.

    Aday görüntü referans görüntülerden biriyle birebir aynıysa eşleşme sayılır;
    böylece istemci tarafında akış uçtan uca denenebilir.
    """

    async def identify(self, images_b64: list[str]) -> ObjectProfile:
        return ObjectProfile(
            valid=bool(images_b64),
            rejection_reason="" if images_b64 else "Fotoğraf yok",
            name="vazo",
            color="mavi",
            material="seramik",
            category="dekorasyon",
            likely_room="salon",
            distinctive_features=["ince boyun", "beyaz çiçek deseni"],
            summary="mavi seramik vazo",
        )

    async def make_hints(self, profile: ObjectProfile) -> AllHints:
        def hs(a: str, b: str, c: str) -> HintSet:
            return HintSet(association=a, attribute=b, location=c)

        return AllHints(
            child=hs("Çiçekler bende su içer!", "Gökyüzü gibi bir rengim var.", "Misafirler gelince beni görür."),
            teen=hs("Bahçeden gelen misafirlerin evi.", "Denizle aynı tondayım.", "Koltukların olduğu odaya bak."),
            adult=hs("Buketlerin geçici adresi.", "Ege'nin rengini toprakta pişirdiler.", "Ev sahibinin vitrini."),
            senior=hs("Bayramda gelen çiçekler bende durur.", "Mavi boncuk rengindeyim.", "Oturma odasında, göz önünde."),
        )

    async def verify(
        self, profile: ObjectProfile, reference_b64: list[str], candidate_b64: str
    ) -> MatchVerdict:
        same = candidate_b64 in reference_b64
        return MatchVerdict(
            same_object=same,
            confidence=1.0 if same else 0.1,
            feedback="Buldun!" if same else "Bu değil, aramaya devam!",
        )


def make_vision() -> Vision:
    mode = os.environ.get("AI_MODE", "claude").lower()
    if mode == "fake":
        log.warning("AI_MODE=fake: sahte görüntü AI'ı kullanılıyor")
        return FakeVision()
    return ClaudeVision()
