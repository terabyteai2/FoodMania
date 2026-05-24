import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class MenuImageView extends StatelessWidget {
  const MenuImageView({
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.iconKey,
    super.key,
  });

  final String? imageUrl;
  final BoxFit fit;

  /// When [imageUrl] is empty/null, the placeholder picks an icon from
  /// [menuIconKeyToIcon] based on this hint. Falls back to a fork+knife.
  final String? iconKey;

  @override
  Widget build(BuildContext context) {
    final image = imageUrl?.trim();
    if (image == null || image.isEmpty) {
      return _ImagePlaceholder(iconKey: iconKey);
    }

    final data = _tryDecodeDataUrl(image);
    if (data != null) {
      return Image.memory(
        data,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            _BrokenImage(iconKey: iconKey),
      );
    }

    return Image.network(
      image,
      fit: fit,
      errorBuilder: (context, error, stackTrace) =>
          _BrokenImage(iconKey: iconKey),
    );
  }

  Uint8List? _tryDecodeDataUrl(String value) {
    final marker = ';base64,';
    if (!value.startsWith('data:image/') || !value.contains(marker)) {
      return null;
    }
    final encoded = value.substring(value.indexOf(marker) + marker.length);
    try {
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({this.iconKey});
  final String? iconKey;

  @override
  Widget build(BuildContext context) {
    final style = menuIconStyleFor(iconKey);
    return Container(
      color: style.background,
      alignment: Alignment.center,
      child: Icon(style.icon, color: style.color, size: 26),
    );
  }
}

class MenuIconStyle {
  const MenuIconStyle({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;
}

/// Foody placeholder palette for scanned/imported menu items without photos.
/// The colors are intentionally distinct so a busy counter can tell items apart
/// at a glance.
MenuIconStyle menuIconStyleFor(String? key) {
  final normalized = (key ?? '').toLowerCase().trim();
  const tomato = Color(0xFFE65A3C);
  const cheese = Color(0xFFF0A51C);
  const curry = Color(0xFFE28714);
  const herb = Color(0xFF3D7A5A);
  const mint = Color(0xFF2E9B79);
  const berry = Color(0xFFC54862);
  const cocoa = Color(0xFF8A5A32);
  const tea = Color(0xFF7A6B2D);
  const sky = Color(0xFF2F7EA8);

  MenuIconStyle s(IconData icon, Color color) {
    return MenuIconStyle(
      icon: icon,
      color: color,
      background: color.withValues(alpha: 0.14),
    );
  }

  switch (normalized) {
    case 'pizza':
      return s(Icons.local_pizza_outlined, tomato);
    case 'burger':
      return s(Icons.lunch_dining_outlined, cheese);
    case 'biryani':
      return s(Icons.rice_bowl_outlined, curry);
    case 'rice':
      return s(Icons.rice_bowl_outlined, tea);
    case 'curry':
      return s(Icons.ramen_dining_outlined, curry);
    case 'soup':
      return s(Icons.ramen_dining_outlined, tomato);
    case 'salad':
    case 'vegetable':
      return s(Icons.eco_outlined, herb);
    case 'noodle':
      return s(Icons.ramen_dining_outlined, berry);
    case 'bread':
      return s(Icons.bakery_dining_outlined, cocoa);
    case 'chicken':
      return s(Icons.set_meal_outlined, tomato);
    case 'fish':
      return s(Icons.set_meal_outlined, sky);
    case 'beef':
      return s(Icons.set_meal_outlined, cocoa);
    case 'snack':
      return s(Icons.fastfood_outlined, cheese);
    case 'fruit':
      return s(Icons.apple_outlined, berry);
    case 'dessert':
      return s(Icons.icecream_outlined, berry);
    case 'drink':
      return s(Icons.local_drink_outlined, mint);
    case 'coffee':
      return s(Icons.coffee_outlined, cocoa);
    case 'tea':
      return s(Icons.emoji_food_beverage_outlined, tea);
    case 'breakfast':
      return s(Icons.breakfast_dining_outlined, cheese);
    case 'set_meal':
    case 'set meal':
    case 'setmeal':
      return s(Icons.dinner_dining_outlined, curry);
    default:
      return s(Icons.restaurant_menu_outlined, PosColors.primaryDark);
  }
}

/// Maps the backend LLM-emitted iconKey to a Material icon used as a default
/// visual when a menu item has no photo. Unknown keys fall back to a generic
/// restaurant icon.
IconData menuIconKeyToIcon(String? key) {
  return menuIconStyleFor(key).icon;
}

class _BrokenImage extends StatelessWidget {
  const _BrokenImage({this.iconKey});
  final String? iconKey;

  @override
  Widget build(BuildContext context) {
    final style = menuIconStyleFor(iconKey);
    return Container(
      color: style.background,
      alignment: Alignment.center,
      child: Icon(style.icon, color: PosColors.muted, size: 22),
    );
  }
}
