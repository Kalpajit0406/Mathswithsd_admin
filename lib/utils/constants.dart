class AppConstants {
  // Use local LAN IP since you are testing on a physical device
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://math-app-backend-main.onrender.com',
  );
  // static const String baseUrl = 'http://10.0.2.2:5000'; // For emulator
  // API Endpoints
  static const String loginEndpoint = '/api/v1/student/login';
  static const String registerEndpoint = '/api/v1/student/register';
  static const String questionsEndpoint = '/api/v1/question/questions';
  static const String createQuestionEndpoint = '/api/v1/question/addQuestion'; // updated
  static const String uploadImageEndpoint = '/api/v1/admin/ocr/scan';
  static const String processOcrEndpoint = '/api/v1/admin/ocr/scan';
  static const String testsEndpoint = '/api/v1/tests';
  static const String createTestEndpoint = '/api/v1/tests/create';
  static const String announcementsEndpoint = '/api/v1/announcements'; // Will be mocked
  static const String bulkDeleteAnnouncementsEndpoint = '/api/v1/announcements/bulk-delete';
  static const String studentsEndpoint = '/api/v1/student/students';
  static const String acceptStudentEndpoint = '/api/v1/student/accept';
  static const String rejectStudentEndpoint = '/api/v1/student/reject';
  static const String bulkAcceptStudentsEndpoint = '/api/v1/student/bulk-accept';
  static const String bulkRejectStudentsEndpoint = '/api/v1/student/bulk-reject';
  static const String bulkDeleteStudentsEndpoint = '/api/v1/student/bulk-delete';
  static const String approveProfileEditEndpoint = '/api/v1/student/approve-profile-edit';
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
  static const String baseUrlOverrideKey = 'api_base_url_override';

  // Class Chapters
  static const Map<int, List<String>> classChapters = {
    9: [
      "Real Numbers",
      "Laws of Indices",
      "Graph",
      "Co-ordinate Geometry: Distance Formula",
      "Linear Simultaneous Equations",
      "Properties of Parallelogram",
      "Polynomial",
      "Factorisation",
      "Transversal & Mid-Point Theorem",
      "Profit and Loss",
      "Statistics",
      "Theorems on Area",
      "Construction: Construction of a Parallelogram whose measurement of one angle is given and equal in area of a Triangle",
      "Construction: Construction of a Triangle equal in area of a Quadrilateral",
      "Area & Perimeter of Triangle & Quadrilateral shaped region",
      "Circumference of Circle",
      "Theorems on Concurrence",
      "Area of Circular Region",
      "Co-ordinate Geometry: Internal and External Division of Straight Line Segment",
      "Co-ordinate Geometry: Area of Triangular Region",
      "Logarithm",
      "Set Theory",
      "Probability Theory"
    ],
    10: [
      "Quadratic equation in one variable",
      "Simple Interest",
      "Theorems related to circle",
      "Rectangular Parallelopiped or Cuboid",
      "Ratio and proportion",
      "Compound Interest and uniform rate of increase or decrease",
      "Theorems related to angles in a circle",
      "Right Circular Cylinder",
      "Quadratic Surd",
      "Theorems related to cyclic quadrilateral",
      "Construction: Circumcircle and Incircle of a triangle",
      "Sphere",
      "Variation",
      "Partnership Business",
      "Theorems related to Tangent to a circle",
      "Right circular cone",
      "Construction: Construction of tangent to a circle",
      "Similarity",
      "Problems on different solid objects",
      "Trigonometry: Measurement of angle",
      "Trigonometric Ratios & Identities",
      "Trigonometric Ratios of complementary angles",
      "Application of Trigonometric Ratios: Heights & Distances",
      "Statistics: Mean, Median, Mode, Ogive"
    ],
    11: [
      "Set Theory",
      "Relation and Function",
      "Trigonometry: Compund Angle",
      "Trigonometry: Multiple Angle",
      "Trigonometry: Sub Multiple Angle",
      "Trigonometry: Sums & Products",
      "Trigonometry: General Solution",
      "Laws of Indices",
      "Logarithm",
      "Mathematical Induction",
      "Complex Numbers",
      "Quadratic Equations",
      "Linear Inequations",
      "Permutation and Combination",
      "Binomial Theorem",
      "Sequence and Series",
      "Two Dimensional Coordinate Geometry",
      "Straight Line",
      "Circle",
      "Parabola",
      "Ellipse",
      "Hyperbola",
      "Three Dimensional Coordinate Geometry",
      "Real Numbers",
      "Limit",
      "Differentiation",
      "Significance of Derivative",
      "Mathematical Reasoning",
      "Statistics",
      "Probability"
    ],
    12: [
      "Relation",
      "Function",
      "Binary Operation",
      "Inverse Trigonometric Function",
      "Types of Matrices and Matrix Algebra",
      "Determinant",
      "Adjoint and Inverse of a Matrix and Solution of Simultaneous Linear Equations",
      "Limit",
      "Continuity and Differentiability",
      "Differentiation",
      "Second Order Derivative",
      "Indefinite Integral",
      "Definite Integral",
      "Differential Equation",
      "Tangent and Normal",
      "Increasing and Decreasing Function",
      "Maxima and Minima",
      "Definite Integral as an Area",
      "Vector Algebra",
      "Product of Two Vectors",
      "Direction Cosines and Direction Ratios",
      "Straight Line in Three Dimensional Space",
      "Plane",
      "Linear Programming",
      "Probability"
    ],
    13: [
      '11',
      '12',
      'Joint',
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
