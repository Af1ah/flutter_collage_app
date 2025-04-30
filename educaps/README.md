# Educaps Flutter Project

## Overview
Educaps is a Flutter application that integrates Firebase for authentication and Supabase for backend services. The app provides a seamless experience for users to log in, access educational content, and manage their profiles.

## Features
- User authentication using Firebase
- Data management and storage with Supabase
- Responsive UI built with Flutter
- Local storage for user preferences

## Project Structure
```
educaps
├── lib
│   ├── main.dart                  # Entry point of the application
│   ├── firebase_options.dart       # Firebase configuration options
│   ├── supabase_client.dart        # Supabase client setup and configuration
│   ├── views
│   │   ├── pages
│   │   │   └── login
│   │   │       └── welcome_page.dart # Welcome page for non-logged-in users
│   │   └── widget_tree.dart        # Main UI structure for logged-in users
├── pubspec.yaml                   # Project dependencies and configuration
└── README.md                      # Project documentation
```

## Setup Instructions

### Prerequisites
- Flutter SDK installed
- Dart SDK installed
- Firebase project set up
- Supabase project set up

### Installation
1. Clone the repository:
   ```
   git clone <repository-url>
   cd educaps
   ```

2. Install dependencies:
   ```
   flutter pub get
   ```

3. Configure Firebase:
   - Add your Firebase configuration file to the project.
   - Update `firebase_options.dart` with your Firebase project settings.

4. Configure Supabase:
   - Create a Supabase project and obtain the API URL and anon key.
   - Update `supabase_client.dart` with your Supabase project settings.

5. Run the application:
   ```
   flutter run
   ```

## Usage
- Launch the app to see the welcome page if not logged in.
- Users can log in or sign up to access the main content of the app.

## Contributing
Contributions are welcome! Please open an issue or submit a pull request for any enhancements or bug fixes.

## License
This project is licensed under the MIT License. See the LICENSE file for details.