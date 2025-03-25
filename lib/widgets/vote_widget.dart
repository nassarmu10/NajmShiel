import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:map_explorer/models/vote.dart';
import 'package:map_explorer/providers/location_data_provider.dart';

class VoteWidget extends StatefulWidget {
  final String locationId;
  
  const VoteWidget({
    Key? key,
    required this.locationId,
  }) : super(key: key);

  @override
  _VoteWidgetState createState() => _VoteWidgetState();
}

class _VoteWidgetState extends State<VoteWidget> {
  bool _isLoading = true;
  VoteSummary _voteSummary = VoteSummary(likes: 0, dislikes: 0);
  VoteType? _userVote;
  
  @override
  void initState() {
    super.initState();
    _loadVotes();
  }

  Future<void> _loadVotes() async {
    setState(() {
      _isLoading = true;
    });
    
    final locationProvider = Provider.of<LocationDataProvider>(context, listen: false);
    
    // Get vote summary and user vote in parallel
    final summaryFuture = locationProvider.getVoteSummary(widget.locationId);
    final userVoteFuture = locationProvider.getUserVote(widget.locationId);
    
    // Wait for both to complete
    final summary = await summaryFuture;
    final userVote = await userVoteFuture;
    
    if (mounted) {
      setState(() {
        _voteSummary = summary;
        _userVote = userVote;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleVote(VoteType voteType) async {
    // If user voted the same way, remove the vote
    if (_userVote == voteType) {
      await _removeVote();
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final locationProvider = Provider.of<LocationDataProvider>(context, listen: false);
      
      await locationProvider.addOrUpdateVote(widget.locationId, voteType);
      
      // Refresh votes
      await _loadVotes();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removeVote() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final locationProvider = Provider.of<LocationDataProvider>(context, listen: false);
      
      await locationProvider.removeVote(widget.locationId);
      
      // Refresh votes
      await _loadVotes();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.thumbs_up_down),
                SizedBox(width: 8),
                Text(
                  'هل توصي بزيارة هذا المكان؟',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              )
            else
              Column(
                children: [
                  // Vote buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Like button
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _handleVote(VoteType.like),
                          icon: Icon(
                            Icons.thumb_up,
                            color: _userVote == VoteType.like
                                ? Colors.green
                                : Colors.grey,
                          ),
                          label: Text(
                            'نعم (${_voteSummary.likes})',
                            style: TextStyle(
                              color: _userVote == VoteType.like
                                  ? Colors.green
                                  : Colors.grey[700],
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                              side: BorderSide(
                                color: _userVote == VoteType.like
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Dislike button
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _handleVote(VoteType.dislike),
                          icon: Icon(
                            Icons.thumb_down,
                            color: _userVote == VoteType.dislike
                                ? Colors.red
                                : Colors.grey,
                          ),
                          label: Text(
                            'لا (${_voteSummary.dislikes})',
                            style: TextStyle(
                              color: _userVote == VoteType.dislike
                                  ? Colors.red
                                  : Colors.grey[700],
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                              side: BorderSide(
                                color: _userVote == VoteType.dislike
                                    ? Colors.red
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // Vote percentage indicator (only show if there are votes)
                  if (_voteSummary.total > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _voteSummary.likePercentage / 100,
                              minHeight: 10,
                              backgroundColor: Colors.red.shade100,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.green.shade400,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_voteSummary.likePercentage.toStringAsFixed(0)}% يوصون بالزيارة',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              Text(
                                'إجمالي الأصوات: ${_voteSummary.total}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
