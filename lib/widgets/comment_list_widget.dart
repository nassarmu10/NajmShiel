import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:map_explorer/models/comment.dart';
import 'package:map_explorer/providers/location_data_provider.dart';
import 'package:map_explorer/widgets/edit_comment.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CommentsList extends StatefulWidget {
  final String locationId;
  
  const CommentsList({
    super.key,
    required this.locationId,
  });

  @override
  CommentsListState createState() => CommentsListState();
}

class CommentsListState extends State<CommentsList> {
  bool _isLoading = true;
  List<Comment> _comments = [];
  
  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
    });
    
    final locationProvider = Provider.of<LocationDataProvider>(context, listen: false);
    final comments = await locationProvider.getCommentsForLocation(widget.locationId);
    
    if (mounted) {
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Icon(Icons.comment),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'التعليقات (${_comments.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadComments,
                  tooltip: 'تحديث التعليقات',
                ),
            ],
          ),
        ),
        if (_comments.isEmpty && !_isLoading)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                'لا توجد تعليقات بعد. كن أول من يترك تعليقًا!',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _comments.length,
            itemBuilder: (context, index) {
              final comment = _comments[index];
              return CommentItem(comment: comment);
            },
          ),
      ],
    );
  }
}

class CommentItem extends StatelessWidget {
  final Comment comment;
  
  const CommentItem({
    super.key,
    required this.comment,
  });

  // Add a method to check if the current user is the comment creator
  bool _isCommentOwner(BuildContext context) {
    final provider = Provider.of<LocationDataProvider>(context, listen: false);
    return provider.isCommentCreator(comment);
  }

  // Show edit/delete menu
  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('تعديل التعليق'),
                onTap: () {
                  Navigator.pop(context); // Close bottom sheet
                  _showEditDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('حذف التعليق', 
                  style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context); // Close bottom sheet
                  _confirmDelete(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('إلغاء'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  // Show edit dialog
  void _showEditDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Important for keyboard handling
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: EditCommentWidget(
            comment: comment,
            onCommentUpdated: () {
              // Refresh the comments list
              final commentsListState = context.findAncestorStateOfType<CommentsListState>();
              if (commentsListState != null) {
                commentsListState._loadComments();
              }
            },
          ),
        );
      },
    );
  }

  // Confirm delete dialog
  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف التعليق'),
        content: const Text('هل أنت متأكد من أنك تريد حذف هذا التعليق؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final provider = Provider.of<LocationDataProvider>(context, listen: false);
                await provider.deleteComment(comment.id, comment.locationId);
                
                // Refresh the comments list
                final commentsListState = context.findAncestorStateOfType<CommentsListState>();
                if (commentsListState != null) {
                  commentsListState._loadComments();
                }
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حذف التعليق بنجاح'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('خطأ: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('MMM d, yyyy - h:mm a').format(comment.createdAt);
    final isOwner = _isCommentOwner(context);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade200,
                  child: Text(
                    comment.username.isNotEmpty 
                        ? comment.username[0].toUpperCase() 
                        : 'A',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.username,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Add options menu for owner
                if (isOwner)
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showOptions(context),
                    tooltip: 'خيارات',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              comment.content,
              style: const TextStyle(fontSize: 15),
              textAlign: TextAlign.right,
            ),
            if (comment.imageUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: comment.imageUrl!,
                    placeholder: (context, url) => Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 100,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.error),
                      ),
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}