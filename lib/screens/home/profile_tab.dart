import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../services/user_profile_service.dart';
import '../../services/connectivity_service.dart';
import '../../widgets/professional_ui_components.dart';
import 'category_management_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isRetrying = false;
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  
  // Selected values
  String _selectedCurrency = 'USD'; // Default
  bool _notificationsEnabled = true; // Default
  
  // Image picking
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  String? _networkImageUrl;

  // Error handling
  int _retryAttempts = 0;
  static const int maxRetryAttempts = 3;
  
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }
  
  // Load user data into form
  void _loadUserData(Map<String, dynamic>? userData) {
    if (userData != null) {
      _nameController.text = userData['displayName'] ?? '';
      _emailController.text = userData['email'] ?? '';
      _selectedCurrency = userData['currency'] ?? 'USD';
      _notificationsEnabled = userData['notificationsEnabled'] ?? true;
      _networkImageUrl = userData['photoURL'];
    }
  }
  
  // Toggle edit mode
  void _toggleEditMode() {
    if (_isEditing) {
      final userProfileService = Provider.of<UserProfileService>(context, listen: false);
      if (mounted) {
        userProfileService.getUserProfile().then((userData) {
          if (mounted) {
            setState(() {
              _loadUserData(userData);
              _isEditing = false;
            });
          }
        });
      }
    } else {
      setState(() {
        _isEditing = true;
      });
    }
  }
  
  // Save profile changes
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (!mounted) return;
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      final userProfileService = Provider.of<UserProfileService>(context, listen: false);
      
      final Map<String, dynamic> updatedProfile = {
        'displayName': _nameController.text.trim(),
        'currency': _selectedCurrency,
        'notificationsEnabled': _notificationsEnabled,
      };
      
      if (_imageFile != null) {
        // Handle image upload if needed
        final imageUrl = await userProfileService.uploadProfileImage(_imageFile!);
        if (imageUrl != null) {
          updatedProfile['photoURL'] = imageUrl;
        }
      }
      
      final success = await userProfileService.updateProfile(updatedProfile);
      
      if (!mounted) return;
      
      if (success) {
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: ProfessionalColors.success,
          ),
        );
      } else {
        setState(() {
          _isSaving = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update profile'),
            backgroundColor: ProfessionalColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isSaving = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: ProfessionalColors.error,
        ),
      );
    }
  }
  
  // Pick image from gallery
  Future<void> _pickImage() async {
    // Store context-dependent objects before async gap
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('CANCEL'),
            ),
          ],
        ),
      );
        if (source == null) return;
      
      // Capture context reference before async operation
      final overlayContext = context;
      // Show loading overlay
      final loadingOverlay = _showLoadingOverlay(overlayContext, 'Processing image...');
      
      // Pick image with reasonable quality for profile pictures
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 800,
        maxHeight: 800,
      );
      
      // Remove overlay
      loadingOverlay.remove();
      
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error picking image: ${e.toString()}'),
          backgroundColor: ProfessionalColors.error,
        ),
      );
    }
  }
  
  // Sign out user
  Future<void> _signOut() async {
    // Store context-dependent objects before async gap
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('SIGN OUT'),
          ),
        ],
      ),
    );
      if (shouldSignOut == true) {
      final authService = Provider.of<AuthService>(context, listen: false);
      try {
        await authService.signOut();
      } catch (e) {
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error signing out: ${e.toString()}'),
            backgroundColor: ProfessionalColors.error,
          ),
        );
      }
    }
  }
  
  // Navigate to category management
  void _navigateToCategoryManagement() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CategoryManagementScreen(),
      ),
    );
  }

  // Retry loading profile with exponential backoff
  Future<void> _retryLoadProfile(UserProfileService userProfileService) async {
    if (_retryAttempts >= maxRetryAttempts) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load profile after multiple attempts. Please check your connection.'),
            backgroundColor: ProfessionalColors.error,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    setState(() {
      _isRetrying = true;
    });

    try {
      // Wait with exponential backoff
      final waitTime = Duration(seconds: math.pow(2, _retryAttempts).toInt());
      await Future.delayed(waitTime);
      
      final userData = await userProfileService.getUserProfile();
      if (mounted) {
        _loadUserData(userData);
        setState(() {
          _isRetrying = false;
          _retryAttempts = 0; // Reset on success
        });
      }
    } catch (e) {
      _retryAttempts++;
      if (mounted) {
        _retryLoadProfile(userProfileService);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProfessionalColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: ProfessionalColors.gray800,
        actions: [
          // Edit/save button
          IconButton(
            onPressed: _isSaving ? null : (_isEditing ? _saveProfile : _toggleEditMode),
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ProfessionalColors.primary,
                    ),
                  )
                : Icon(_isEditing ? Icons.save : Icons.edit),
            tooltip: _isEditing ? 'Save profile' : 'Edit profile',
          ),
          if (_isEditing)
            IconButton(
              onPressed: _toggleEditMode,
              icon: const Icon(Icons.close),
              tooltip: 'Cancel editing',
            ),
        ],
      ),
      body: Consumer<UserProfileService>(
        builder: (context, userProfileService, _) {
          return FutureBuilder<Map<String, dynamic>?>(
            future: userProfileService.getUserProfile(),
            builder: (context, snapshot) {
              // Show loading while fetching data
              if (snapshot.connectionState == ConnectionState.waiting && !_isRetrying) {
                return const Center(child: CircularProgressIndicator());
              }
              
              // Handle errors
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off,
                        size: 48,
                        color: ProfessionalColors.error
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Unable to load profile',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isRetrying 
                          ? 'Retrying... (Attempt ${_retryAttempts + 1}/$maxRetryAttempts)'
                          : 'Please check your connection',
                        style: const TextStyle(color: ProfessionalColors.gray600),
                      ),
                      const SizedBox(height: 24),
                      if (!_isRetrying)
                        ElevatedButton.icon(
                          onPressed: () => _retryLoadProfile(userProfileService),
                          icon: const Icon(Icons.refresh),                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ProfessionalColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                );
              }
              
              // Load user data only on first build or when not editing
              if (!_isEditing || _nameController.text.isEmpty) {
                _loadUserData(snapshot.data);
              }
              
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Image and Personal Info
                      _buildProfileCard(),
                      const SizedBox(height: 24),
                      
                      // Settings
                      _buildSettingsCard(),
                      const SizedBox(height: 24),
                      
                      // App Options
                      _buildAppOptionsCard(),
                      const SizedBox(height: 24),
                      
                      // Sign Out Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _signOut,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ProfessionalColors.gray200,
                            foregroundColor: ProfessionalColors.gray800,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign Out'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
  
  Widget _buildProfileCard() {
    return ProfessionalCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Profile Image
          GestureDetector(
            onTap: _isEditing ? _pickImage : null,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                // Profile Image
                CircleAvatar(
                  radius: 50,
                  backgroundColor: ProfessionalColors.gray200,
                  backgroundImage: _getProfileImage(),
                  child: _imageFile == null && _networkImageUrl == null
                      ? const Icon(
                          Icons.person,
                          size: 50,
                          color: ProfessionalColors.gray400,
                        )
                      : null,
                ),
                
                // Edit Icon
                if (_isEditing)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: ProfessionalColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Name Field
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Display Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            enabled: _isEditing,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Display name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Email Field (read-only)
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email),
            ),
            enabled: false, // Email can't be edited here
          ),          // Email verification status
          
          // Email verification status
          Consumer<AuthService>(
            builder: (context, authService, _) {
              final user = authService.user;
              final isVerified = user?.emailVerified ?? false;
              
              if (user == null) return const SizedBox.shrink();
              
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(
                      isVerified ? Icons.verified : Icons.warning,
                      size: 16,
                      color: isVerified ? ProfessionalColors.success : ProfessionalColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isVerified ? 'Email verified' : 'Email not verified',
                      style: TextStyle(
                        fontSize: 12,
                        color: isVerified ? ProfessionalColors.success : ProfessionalColors.warning,
                      ),
                    ),
                    if (!isVerified)                      TextButton(
                        onPressed: () async {
                          // Store context-dependent objects before async gap
                          if (!mounted) return;
                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          final userProfileService = Provider.of<UserProfileService>(context, listen: false);
                          
                          try {
                            // Show loading indicator
                            final loadingOverlay = _showLoadingOverlay(context, 'Sending verification email...');
                            
                            await userProfileService.sendEmailVerification();
                            
                            // Hide loading indicator
                            loadingOverlay.remove();
                            
                            if (!mounted) return;
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('Verification email sent'),
                                backgroundColor: ProfessionalColors.success,
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            // Use the scaffoldMessenger that was stored before the async gap
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text('Error: ${e.toString()}'),
                                backgroundColor: ProfessionalColors.error,
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Verify Now',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildSettingsCard() {
    return ProfessionalCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ProfessionalColors.gray800,
            ),
          ),
          const SizedBox(height: 16),
          
          // Currency Selection
          Consumer<UserProfileService>(
            builder: (context, userProfileService, _) {
              return Row(
                children: [
                  const Icon(
                    Icons.currency_exchange,
                    color: ProfessionalColors.primary,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Currency',
                    style: TextStyle(
                      fontSize: 16,
                      color: ProfessionalColors.gray700,
                    ),
                  ),
                  const Spacer(),
                  if (_isEditing)
                    // Dropdown for editing
                    DropdownButton<String>(
                      value: _selectedCurrency,
                      items: _buildCurrencyDropdownItems(userProfileService),                      onChanged: (String? newValue) {
                        if (newValue != null && newValue != _selectedCurrency) {
                          setState(() {
                            _selectedCurrency = newValue;
                          });
                          
                          // Show brief feedback
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Currency changed to $newValue'),
                              backgroundColor: ProfessionalColors.primary,
                              duration: const Duration(seconds: 1),
                              action: SnackBarAction(
                                label: 'OK',
                                textColor: Colors.white,
                                onPressed: () {
                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                },
                              ),
                            ),
                          );
                        }
                      },
                    )
                  else
                    // Read-only display
                    Row(
                      children: [
                        Text(
                          '${userProfileService.getCurrencySymbol(_selectedCurrency)} $_selectedCurrency',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          
          // Notification Settings
          Row(
            children: [
              const Icon(
                Icons.notifications,
                color: ProfessionalColors.primary,
              ),
              const SizedBox(width: 12),
              const Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 16,
                  color: ProfessionalColors.gray700,
                ),
              ),
              const Spacer(),
              if (_isEditing)
                // Switch for editing
                Switch(
                  value: _notificationsEnabled,
                  activeColor: ProfessionalColors.primary,
                  onChanged: (value) {
                    setState(() {
                      _notificationsEnabled = value;
                    });
                  },
                )
              else
                // Read-only display
                Row(
                  children: [
                    Icon(
                      _notificationsEnabled ? Icons.check_circle : Icons.cancel,
                      color: _notificationsEnabled
                          ? ProfessionalColors.success
                          : ProfessionalColors.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _notificationsEnabled ? 'Enabled' : 'Disabled',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _notificationsEnabled
                            ? ProfessionalColors.success
                            : ProfessionalColors.error,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildAppOptionsCard() {
    return ProfessionalCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'App Options',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ProfessionalColors.gray800,
            ),
          ),
          const SizedBox(height: 16),
            // Category Management
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ProfessionalColors.primary.withAlpha(26),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: ProfessionalColors.primary.withAlpha(77),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.category,
                color: ProfessionalColors.primary,
                size: 22,
              ),
            ),
            title: const Text(
              'Category Management',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: const Text(
              'Create, edit, and delete custom categories',
              style: TextStyle(
                fontSize: 13,
                color: ProfessionalColors.gray600,
              ),
            ),
            trailing: Container(
              decoration: BoxDecoration(
                color: ProfessionalColors.primary.withAlpha(13),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(
                  Icons.chevron_right,
                  color: ProfessionalColors.primary,
                ),
              ),
            ),
            onTap: _navigateToCategoryManagement,
          ),
          const Divider(),
          
          // Connectivity Status
          Consumer<ConnectivityService>(
            builder: (context, connectivity, _) {
              return ListTile(
                contentPadding: EdgeInsets.zero,                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (connectivity.isOnline)
                        ? ProfessionalColors.success.withAlpha(25)
                        : ProfessionalColors.error.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    (connectivity.isOnline) ? Icons.cloud_done : Icons.cloud_off,
                    color: (connectivity.isOnline)
                        ? ProfessionalColors.success
                        : ProfessionalColors.error,
                  ),
                ),                title: Text(
                  (connectivity.isOnline) ? 'Connected' : 'Offline',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: (connectivity.isOnline)
                        ? ProfessionalColors.success
                        : ProfessionalColors.error,
                  ),
                ),
                subtitle: Text(
                  (connectivity.isOnline)
                      ? 'Data syncing normally'
                      : 'Changes will sync when connected',
                ),
                trailing: (connectivity.isOnline)
                    ? null
                    : TextButton(
                        onPressed: () => connectivity.forceReconnect(),
                        child: const Text('Try Connect'),
                      ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  // Build currency dropdown items
  List<DropdownMenuItem<String>> _buildCurrencyDropdownItems(UserProfileService service) {
    return [
      _buildCurrencyDropdownItem(service, 'USD', 'US Dollar'),
      _buildCurrencyDropdownItem(service, 'EUR', 'Euro'),
      _buildCurrencyDropdownItem(service, 'GBP', 'British Pound'),
      _buildCurrencyDropdownItem(service, 'JPY', 'Japanese Yen'),
      _buildCurrencyDropdownItem(service, 'CAD', 'Canadian Dollar'),
      _buildCurrencyDropdownItem(service, 'AUD', 'Australian Dollar'),
      _buildCurrencyDropdownItem(service, 'CHF', 'Swiss Franc'),
      _buildCurrencyDropdownItem(service, 'CNY', 'Chinese Yuan'),
      _buildCurrencyDropdownItem(service, 'INR', 'Indian Rupee'),
      _buildCurrencyDropdownItem(service, 'KRW', 'South Korean Won'),
    ];
  }
  
  // Build individual currency dropdown item
  DropdownMenuItem<String> _buildCurrencyDropdownItem(
    UserProfileService service,
    String code,
    String name,
  ) {
    return DropdownMenuItem<String>(
      value: code,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(service.getCurrencySymbol(code)),
          const SizedBox(width: 4),
          Text(code),
        ],
      ),
    );
  }
    // Get profile image (either from file or network)
  ImageProvider? _getProfileImage() {
    if (_imageFile != null) {
      return FileImage(_imageFile!);
    } else if (_networkImageUrl != null) {
      return NetworkImage(_networkImageUrl!);
    }
    return null;
  }
  
  // Show loading overlay helper
  OverlayEntry _showLoadingOverlay(BuildContext context, String message) {
    // Capture the overlay state before the async gap
    final overlayState = Overlay.of(context);
    
    final overlay = OverlayEntry(
      builder: (context) => Container(
        color: Colors.black.withAlpha(128),
        child: Center(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Text(
                      message,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    
    // Add overlay to the screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      overlayState.insert(overlay);
    });
    
    return overlay;
  }
  
  // Removed unused method

}