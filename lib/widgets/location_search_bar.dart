import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../services/geocoding_service.dart';

/// Google-Maps-style search input with a typeahead dropdown of place
/// suggestions. The dropdown floats below the input; tapping a suggestion
/// fires [onSelected] so the parent can move its map and drop a pin.
///
/// Renders only the input field + dropdown — the parent is responsible for
/// any leading/trailing icon buttons (back, reset, etc.) so the same widget
/// fits screens with different chrome.
class LocationSearchBar extends StatefulWidget {
  const LocationSearchBar({
    super.key,
    required this.proximity,
    required this.onSelected,
    this.selectedLabel,
    this.hintText = 'Search location',
  });

  /// Bias suggestions toward the current map center.
  final LatLng proximity;
  final ValueChanged<GeocodeResult> onSelected;

  /// Label of the most recently picked place; populated into the input so the
  /// user can see what's currently shown on the map.
  final String? selectedLabel;

  final String hintText;

  @override
  State<LocationSearchBar> createState() => _LocationSearchBarState();
}

class _LocationSearchBarState extends State<LocationSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  /// Debounce so we don't hit the geocoder on every keystroke.
  Timer? _debounce;

  /// Monotonic token that lets us drop stale results when the user keeps
  /// typing while an earlier request is still in flight.
  int _queryToken = 0;

  List<GeocodeResult> _results = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.selectedLabel != null) _controller.text = widget.selectedLabel!;
    _focus.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant LocationSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final label = widget.selectedLabel;
    if (label != null && !_focus.hasFocus && _controller.text != label) {
      _controller.text = label;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = const [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    final token = ++_queryToken;
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final r = await GeocodingService.instance
          .search(trimmed, proximity: widget.proximity);
      if (!mounted || token != _queryToken) return;
      setState(() {
        _results = r;
        _loading = false;
      });
    });
  }

  void _clear() {
    _controller.clear();
    _queryToken++;
    _debounce?.cancel();
    setState(() {
      _results = const [];
      _loading = false;
    });
  }

  void _select(GeocodeResult r) {
    _controller.text = r.text;
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
    _focus.unfocus();
    setState(() => _results = const []);
    widget.onSelected(r);
  }

  @override
  Widget build(BuildContext context) {
    final hasFocus = _focus.hasFocus;
    final hasText = _controller.text.isNotEmpty;
    final showDropdown =
        hasFocus && hasText && (_loading || _results.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: hasFocus
                  ? const Color(0xFFDADCE0)
                  : const Color(0x0F000000),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: hasFocus
                    ? const Color(0x1A000000)
                    : const Color(0x12000000),
                blurRadius: hasFocus ? 18 : 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded,
                  color: Color(0xFF5F6368), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  onChanged: _onChanged,
                  textInputAction: TextInputAction.search,
                  cursorColor: const Color(0xFF1F1F1F),
                  // Override the app-wide InputDecorationTheme (which has
                  // filled:true + a tinted fillColor) so the input is
                  // visually seamless with the surrounding white pill.
                  decoration: InputDecoration(
                    filled: false,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: widget.hintText,
                    hintStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF9AA0A6),
                      letterSpacing: -0.2,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1F1F1F),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (hasText) ...[
                const SizedBox(width: 8),
                InkResponse(
                  onTap: _clear,
                  radius: 18,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F3F4),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.close_rounded,
                        color: Color(0xFF5F6368), size: 16),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (showDropdown) ...[
          const SizedBox(height: 6),
          Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x0F000000), width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < _results.length; i++) ...[
                          if (i > 0)
                            const Divider(
                              height: 1,
                              thickness: 1,
                              indent: 56,
                              color: Color(0x0F000000),
                            ),
                          _SuggestionTile(
                            result: _results[i],
                            onTap: () => _select(_results[i]),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.result, required this.onTap});
  final GeocodeResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final showSecondary =
        result.placeName.isNotEmpty && result.placeName != result.text;
    return InkWell(
      onTap: onTap,
      hoverColor: const Color(0x08000000),
      splashColor: const Color(0x14000000),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F3F4),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.place_outlined,
                  color: Color(0xFF5F6368), size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.text,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF202124),
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (showSecondary) ...[
                    const SizedBox(height: 2),
                    Text(
                      result.placeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5F6368),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
