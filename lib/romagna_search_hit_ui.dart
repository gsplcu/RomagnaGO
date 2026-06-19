import 'package:flutter/material.dart';

import 'photon_romagna.dart';
import 'romagna_brand.dart';

/// Icona e colore per un risultato di ricerca (Photon OSM / fermata TPL).
Widget romagnaSearchHitLeading(RomagnaAddressHit hit, {double size = 22}) {
  if (hit.isSearchMessage) {
    return Icon(
      Icons.info_outline_rounded,
      size: size,
      color: Colors.grey.shade500,
    );
  }
  if (hit.isMetromareStop ||
      (hit.transitStopCode?.trim().toUpperCase().startsWith('TRC') ?? false)) {
    return Container(
      width: size + 2,
      height: size + 2,
      decoration: const BoxDecoration(
        color: kMetromareRed,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        'M',
        style: TextStyle(
          fontSize: size * 0.58,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
  return Icon(
    romagnaSearchHitIcon(hit),
    size: size,
    color: romagnaSearchHitColor(hit),
  );
}

IconData romagnaSearchHitIcon(RomagnaAddressHit hit) {
  if (hit.isFerryStop) return Icons.directions_boat_filled_rounded;
  if (hit.isBusStop) return Icons.directions_bus_rounded;

  switch (hit.poiCategory) {
    case RomagnaSearchPoiCategory.beach:
      return Icons.beach_access_rounded;
    case RomagnaSearchPoiCategory.iceCream:
      return Icons.icecream_outlined;
    case RomagnaSearchPoiCategory.cafeBar:
      return Icons.local_cafe_rounded;
    case RomagnaSearchPoiCategory.restaurant:
      return Icons.restaurant_rounded;
    case RomagnaSearchPoiCategory.foodOther:
      return Icons.restaurant_menu_rounded;
    case RomagnaSearchPoiCategory.monument:
      return Icons.account_balance_rounded;
    case RomagnaSearchPoiCategory.shop:
      return Icons.storefront_outlined;
    case RomagnaSearchPoiCategory.genericPoi:
      return Icons.place_outlined;
    case RomagnaSearchPoiCategory.street:
      return Icons.alt_route_rounded;
    case RomagnaSearchPoiCategory.cityOrTown:
      return Icons.location_city_rounded;
    case RomagnaSearchPoiCategory.villageOrHamlet:
      return Icons.location_on_rounded;
    case RomagnaSearchPoiCategory.addressBuilding:
      return Icons.home_work_outlined;
    case RomagnaSearchPoiCategory.other:
      return Icons.place_outlined;
  }
}

Color romagnaSearchHitColor(RomagnaAddressHit hit) {
  if (hit.isSearchMessage) return kRomagnaDarkGray.withValues(alpha: 0.5);
  if (hit.isFerryStop) return kFerryElectricBlue;
  if (hit.isMetromareStop ||
      (hit.transitStopCode?.trim().toUpperCase().startsWith('TRC') ?? false)) {
    return kMetromareRed;
  }
  if (hit.isBusStop) return const Color(0xFFFF8A00);

  switch (hit.poiCategory) {
    case RomagnaSearchPoiCategory.beach:
      return const Color(0xFF0288D1);
    case RomagnaSearchPoiCategory.iceCream:
    case RomagnaSearchPoiCategory.cafeBar:
    case RomagnaSearchPoiCategory.restaurant:
    case RomagnaSearchPoiCategory.foodOther:
      return const Color(0xFF2E7D32);
    case RomagnaSearchPoiCategory.monument:
    case RomagnaSearchPoiCategory.shop:
    case RomagnaSearchPoiCategory.genericPoi:
      return const Color(0xFFE65100);
    case RomagnaSearchPoiCategory.street:
    case RomagnaSearchPoiCategory.cityOrTown:
    case RomagnaSearchPoiCategory.villageOrHamlet:
    case RomagnaSearchPoiCategory.addressBuilding:
    case RomagnaSearchPoiCategory.other:
      return kRomagnaPrimary.withValues(alpha: 0.88);
  }
}
