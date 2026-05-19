class AppConstants {
  // Use local LAN IP since you are testing on a physical device
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.37.148.209:5000',
  );
  // static const String baseUrl = 'http://10.0.2.2:5000'; // For emulator
  // API Endpoints
  static const String loginEndpoint = '/api/v1/student/login';
  static const String registerEndpoint = '/api/v1/student/register';
  static const String questionsEndpoint = '/api/v1/question/questions';
  static const String createQuestionEndpoint = '/api/v1/question/addQuestion'; // updated
  static const String uploadImageEndpoint = '/api/v1/scan'; // updated
  static const String processOcrEndpoint = '/api/v1/scan/process'; // Assuming this or similar, wait I will handle OCR in dart if it doesn't exist
  static const String testsEndpoint = '/api/v1/tests';
  static const String createTestEndpoint = '/api/v1/tests/create';
  static const String announcementsEndpoint = '/api/v1/announcements'; // Will be mocked
  static const String studentsEndpoint = '/api/v1/student/students';
  static const String acceptStudentEndpoint = '/api/v1/student/accept';
  static const String rejectStudentEndpoint = '/api/v1/student/reject';
  static const String startAttemptEndpoint = '/api/v1/testResponse/start';
  static const String submitAttemptEndpoint = '/api/v1/testResponse/submit';
  static const String testResponseEndpoint = '/api/v1/testResponse';

  // Storage Keys
  static const String tokenKey = 'access_token';
  static const String isAdminKey = 'is_admin';
  static const String userPhoneKey = 'user_phone';
  static const String userClassKey = 'user_class';
  static const String userFirstNameKey = 'user_first_name';
  static const String userLastNameKey = 'user_last_name';

  // Class Chapters
  static const Map<int, List<String>> classChapters = {
    9: [
      'Real Numbers',
      'Laws of Indices',
      'Graph',
      'Co-ordinate Geometry: Distance Formula',
      'Linear Simultaneous Equations',
      'Properties of Parallelogram',
      'Polynomial',
      'Factorisation',
      'Transversal and Mid-Point Theorem',
      'Profit and Loss',
      'Statistics',
      'Theorems on Area',
      'Construction: Parallelogram Equal in Area to a Triangle',
      'Construction: Triangle Equal in Area to a Quadrilateral',
      'Area & Perimeter of Triangle and Quadrilateral',
      'Circumference of Circle',
      'Concurrent Theorems',
      'Area of Circle',
      'Co-ordinate Geometry: Internal and External Division',
      'Co-ordinate Geometry: Area of Triangular Region',
      'Logarithm',
    ],
    10: [
      'Quadratic Equation in One Variable',
      'Simple Interest',
      'Theorems Related to Circle',
      'Rectangular Parallelepiped or Cuboid',
      'Ratio and Proportion',
      'Compound Interest and Uniform Rate of Increase or Decrease',
      'Theorems Related to Angles in a Circle',
      'Right Circular Cylinder',
      'Quadratic Surd',
      'Theorems Related to Cyclic Quadrilateral',
      'Construction: Construction of Circumcircle and Incircle of a Triangle',
      'Sphere',
      'Variation',
      'Partnership Business',
      'Theorems Related to Tangent to a Circle',
      'Right Circular Cone',
      'Construction: Construction of Tangent to a Circle',
      'Similarity',
      'Problems Related to Different Solid Objects',
      'Trigonometry: Concept of Measurement of Angle',
      'Construction: Determination of Mean Proportional',
      'Pythagoras Theorem',
      'Trigonometric Ratios and Trigonometric Identities',
      'Trigonometric Ratios of Complementary Angles',
      'Application of Trigonometric Ratios: Heights and Distances',
      'Statistics: Mean, Median, Ogive, Mode',
    ],
    11: [
      'Sets',
      'Relations and Functions',
      'Trigonometric Functions',
      'Principle of Mathematical Induction',
      'Complex Numbers and Quadratic Equations',
      'Linear Inequalities',
      'Permutations and Combinations',
      'Binomial Theorem',
      'Sequences and Series',
      'Straight Lines',
      'Conic Sections',
      'Introduction to Three-dimensional Geometry',
      'Limits and Derivatives',
      'Mathematical Reasoning',
      'Statistics',
      'Probability',
    ],
    12: [
      'Relations and Functions',
      'Inverse Trigonometric Functions',
      'Matrices',
      'Determinants',
      'Continuity and Differentiability',
      'Application of Derivatives',
      'Integrals',
      'Application of Integrals',
      'Differential Equations',
      'Vector Algebra',
      'Three Dimensional Geometry',
      'Linear Programming',
      'Probability',
    ],
  };
}

class AppColors {
  // Admin Theme - Teal/Cyan
  static const int adminPrimary = 0xFF006064;
  static const int adminLight = 0xFFE0F7FA;
  static const int adminAccent = 0xFF00BCD4;

  // Student Theme - Purple
  static const int studentPrimary = 0xFF4A148C;
  static const int studentLight = 0xFFF3E5F5;
  static const int studentAccent = 0xFF9C27B0;

  // General
  static const int teal = 0xFF009688;
  static const int deepPurple = 0xFF673AB7;
  static const int blue = 0xFF1565C0;
  static const int orange = 0xFFFF9800;
  static const int pink = 0xFFE91E63;
  static const int green = 0xFF43A047;
  static const int red = 0xFFE53935;
  static const int gold = 0xFFFFD700;

  // Answer palette
  static const int answered = 0xFF43A047;
  static const int markedReview = 0xFF9C27B0;
  static const int unanswered = 0xFF9E9E9E;
  static const int current = 0xFF1565C0;
}
