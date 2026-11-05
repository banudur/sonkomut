"""Ortak veri modelleri: yaş grupları, AI çıktıları."""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum

from pydantic import BaseModel, Field


class AgeBand(str, Enum):
    CHILD = "child"    # 7-10
    TEEN = "teen"      # 11-15
    ADULT = "adult"    # 16-55
    SENIOR = "senior"  # 56-70


AGE_BAND_LABELS = {
    AgeBand.CHILD: "7-10 yaş",
    AgeBand.TEEN: "11-15 yaş",
    AgeBand.ADULT: "16-55 yaş",
    AgeBand.SENIOR: "56-70 yaş",
}


class ObjectProfile(BaseModel):
    """Saklayanın taradığı nesnenin AI tarafından çıkarılan profili."""

    valid: bool = Field(description="Görüntülerde tek ve net bir ev nesnesi var mı")
    rejection_reason: str = Field(description="valid=false ise Türkçe kısa sebep, değilse boş")
    name: str = Field(description="Nesnenin Türkçe adı, örn. 'vazo'")
    color: str = Field(description="Baskın renk, Türkçe, örn. 'mavi'")
    material: str = Field(description="Malzeme, Türkçe, örn. 'seramik'")
    category: str = Field(description="Genel kategori, örn. 'dekorasyon'")
    likely_room: str = Field(description="Evde bulunabileceği oda, örn. 'salon'")
    distinctive_features: list[str] = Field(
        description="Aynı türdeki başka nesnelerden ayırt ettiren görsel özellikler"
    )
    summary: str = Field(description="Saklayana gösterilecek kısa Türkçe özet, örn. 'mavi seramik vazo'")


class HintSet(BaseModel):
    """Bir yaş grubu için kolaydan zora değil, uzaktan yakına giden 3 ipucu."""

    association: str = Field(description="1. seviye: nesnenin adını/rengini söylemeden çağrışım")
    attribute: str = Field(description="2. seviye: renk veya malzeme gibi bir özelliği ima eden ipucu")
    location: str = Field(description="3. seviye: nerede olabileceğine dair ipucu, adı söylemeden")


class MatchVerdict(BaseModel):
    """Ebenin taradığı görüntü saklanan nesneyle aynı mı?"""

    same_object: bool = Field(description="Aday görüntü referanstaki AYNI fiziksel nesne mi")
    confidence: float = Field(description="0 ile 1 arası güven")
    feedback: str = Field(
        description="Ebeye gösterilecek kısa Türkçe geri bildirim; eşleşmiyorsa nesneyi ele vermeden"
    )


class AllHints(BaseModel):
    """Dört yaş grubu için ipucu setleri (tek AI çağrısında üretilir)."""

    child: HintSet
    teen: HintSet
    adult: HintSet
    senior: HintSet

    def for_band(self, band: AgeBand) -> HintSet:
        return getattr(self, band.value)


@dataclass
class Identification:
    """Tanıma sonucu + saklayanın düzeltebilmesi için seçenekler."""

    profile: ObjectProfile
    alternatives: list[str] = field(default_factory=list)  # olası adlar
    needs_name: bool = False                               # AI emin değil, saklayan seçmeli
    colors: list[str] = field(default_factory=list)        # seçilebilir renkler
