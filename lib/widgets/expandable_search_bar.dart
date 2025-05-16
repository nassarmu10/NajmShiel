import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:map_explorer/providers/location_data_provider.dart';
import 'package:map_explorer/models/location.dart';
import 'package:map_explorer/utils/location_type_utils.dart';

class ExpandableSearchBar extends StatefulWidget {
  final Function(Location) onLocationSelected;

  const ExpandableSearchBar({
    Key? key,
    required this.onLocationSelected,
  }) : super(key: key);

  @override
  _ExpandableSearchBarState createState() => _ExpandableSearchBarState();
}

class _ExpandableSearchBarState extends State<ExpandableSearchBar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final TextEditingController _searchController = TextEditingController();
  List<Location> _searchResults = [];
  bool _isExpanded = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _searchController.text.isEmpty) {
        _collapse();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _expand() {
    setState(() {
      _isExpanded = true;
    });
    _controller.forward();
    _focusNode.requestFocus();
  }

  void _collapse() {
    _controller.reverse().then((_) {
      setState(() {
        _isExpanded = false;
        _searchResults = [];
      });
    });
  }

  void _performSearch(String query) {
    final provider = Provider.of<LocationDataProvider>(context, listen: false);
    setState(() {
      _searchResults = provider.searchLocations(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (!_isExpanded)
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _expand,
            tooltip: 'بحث',
          ),
        if (_isExpanded)
          Expanded(
            child: Stack(
              children: [
                // Search TextField
                SizeTransition(
                  sizeFactor: _animation,
                  axis: Axis.horizontal,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        hintText: 'ابحث عن موقع...',
                        hintTextDirection: TextDirection.rtl,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchResults = [];
                            });
                            _collapse();
                          },
                        ),
                      ),
                      onChanged: _performSearch,
                    ),
                  ),
                ),
                // Search Results Overlay
                if (_searchResults.isNotEmpty)
                  Positioned(
                    top: 45, // Below the search bar
                    left: 0,
                    right: 0,
                    child: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.4,
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final location = _searchResults[index];
                            return ListTile(
                              title: Text(
                                location.name,
                                textDirection: TextDirection.rtl,
                              ),
                              subtitle: Text(
                                location.description,
                                textDirection: TextDirection.rtl,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              leading: Icon(
                                LocationTypeUtils.getIcon(location.type),
                                color: Theme.of(context).primaryColor,
                              ),
                              onTap: () {
                                widget.onLocationSelected(location);
                                _searchController.clear();
                                setState(() {
                                  _searchResults = [];
                                });
                                _collapse();
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
} 