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
  final normalized = (key ?? '')
      .toLowerCase()
      .trim()
      .replaceAll('-', '_')
      .replaceAll(' ', '_');
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
    case 'sandwich':
    case 'sandwitch':
      return s(Icons.lunch_dining_outlined, cheese);
    case 'biryani':
      return s(Icons.rice_bowl_outlined, curry);
    case 'rice':
      return s(Icons.rice_bowl_outlined, tea);
    case 'curry':
      return s(Icons.ramen_dining_outlined, curry);
    case 'soup':
      return s(Icons.ramen_dining_outlined, tomato);
    case 'dal':
    case 'daal':
      return s(Icons.ramen_dining_outlined, tea);
    case 'salad':
    case 'vegetable':
      return s(Icons.eco_outlined, herb);
    case 'noodle':
    case 'noodles':
    case 'pasta':
      return s(Icons.ramen_dining_outlined, berry);
    case 'bread':
      return s(Icons.bakery_dining_outlined, cocoa);
    case 'chicken':
      return s(Icons.set_meal_outlined, tomato);
    case 'fish':
      return s(Icons.set_meal_outlined, sky);
    case 'beef':
    case 'mutton':
      return s(Icons.set_meal_outlined, cocoa);
    case 'kebab':
    case 'grill':
      return s(Icons.dinner_dining_outlined, curry);
    case 'appetizer':
    case 'starter':
    case 'starters':
    case 'fuchka':
    case 'snack':
      return s(Icons.fastfood_outlined, cheese);
    case 'fruit':
    case 'juice':
      return s(Icons.apple_outlined, berry);
    case 'dessert':
    case 'desserts':
    case 'sweets':
      return s(Icons.icecream_outlined, berry);
    case 'drink':
    case 'beverages':
    case 'soft_drink':
      return s(Icons.local_drink_outlined, mint);
    case 'coffee':
    case 'tea_coffee':
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

String inferMenuIconKey({required String name, String? category}) {
  final text = '${name.toLowerCase()} ${(category ?? '').toLowerCase()}';
  bool has(Iterable<String> words) => words.any(text.contains);

  if (has(['burger'])) return 'burger';
  if (has(['sandwich', 'sandwitch'])) return 'sandwich';
  if (has([
    'biryani',
    'biriyani',
    'kacchi',
    'tehari',
    'polao',
    'পোলাও',
    'বিরিয়ানি',
  ])) {
    return 'biryani';
  }
  if (has(['rice', 'fried rice', 'ভাত'])) return 'biryani';
  if (has(['dal', 'daal', 'lentil', 'ডাল'])) return 'dal';
  if (has(['grill', 'grilled', 'bbq', 'barbecue'])) return 'grill';
  if (has(['kebab', 'kabab', 'কাবাব'])) return 'kebab';
  if (has(['soup'])) return 'soup';
  if (has(['salad', 'veg', 'vegetable', 'সবজি'])) return 'vegetable';
  if (has(['noodle', 'chowmein', 'chow mein'])) return 'noodles';
  if (has(['pasta', 'spaghetti', 'macaroni'])) return 'pasta';
  if (has(['bread', 'naan', 'paratha', 'রুটি', 'পরোটা'])) return 'appetizer';
  if (has(['chicken', 'চিকেন', 'মুরগি'])) return 'chicken';
  if (has(['fish', 'prawn', 'shrimp', 'rui', 'ilish', 'মাছ'])) return 'fish';
  if (has(['mutton', 'খাসি'])) return 'mutton';
  if (has(['beef', 'গরু'])) return 'beef';
  if (has(['snack', 'samosa', 'roll', 'fries', 'singara', 'সমুচা'])) {
    return 'appetizer';
  }
  if (has(['fuchka', 'ফুচকা'])) return 'fuchka';
  if (has(['juice'])) return 'juice';
  if (has(['dessert', 'sweet', 'cake', 'firni', 'ice cream', 'মিষ্টি'])) {
    return 'sweets';
  }
  if (has(['water', 'পানি'])) return 'water';
  if (has(['soft drink', 'softdrink', 'soda', 'cola'])) return 'soft_drink';
  if (has(['drink', 'soda', 'lassi', 'borhani', 'beverage', 'পানীয়'])) {
    return 'beverages';
  }
  if (has(['coffee'])) return 'tea_coffee';
  if (has(['tea', 'cha', 'চা'])) return 'tea_coffee';
  if (has(['breakfast', 'omelet', 'omelette'])) return 'breakfast';
  if (has(['set meal', 'set_menu', 'combo', 'platter', 'থালি'])) {
    return 'biryani';
  }
  return 'general';
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
