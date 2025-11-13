# FinView Lite

FinView Lite is a Flutter-based mobile and web dashboard app designed to provide users with a clean, minimalistic wealth management experience. It visualizes users' investment portfolios, asset allocation, and returns using local mock JSON data without requiring any backend. The app is responsive, featuring an attractive UI/UX for easy investment insights.

## Features

- Displays portfolio summary including total portfolio value and total gain/loss.
- Shows individual holdings with detailed information: asset name, units held, average cost, current value, and gain/loss.
- Visual representation of asset allocation via interactive pie charts using the free FL Chart library.
- Allows toggling returns view between percentage and absolute amount.
- Sorting functionality to sort holdings by value, gain, or name.
- Handles scenarios with no data or zero investments gracefully.
- Supports dark and light modes with smooth theme toggle.
- Uses local JSON file (`assets/portfolio.json`) to simulate API data.
- Includes mock authentication with username entry and persistent login state using Shared Preferences.

- ![Screenshots](https://drive.google.com/drive/folders/1-faj3C-OQLnRDSnlk8Zs8-5mzalv0uqq?usp=drive_link)

- [Demo Video](https://drive.google.com/file/d/12C9Re2oSG-xyKIP1qRi_nMtQj4UjoDtc/view?usp=drive_link)



## Setup Instructions

1. Ensure you have [Flutter 3.35.7](https://docs.flutter.dev/release/whats-new) installed on your system.
2. Clone the repository:

3. Get dependencies:

4. Run the app:

- For Android emulator or device:

5. The app uses the `assets/portfolio.json` file as the mock data source. Ensure it is present in the assets directory and properly linked in `pubspec.yaml`.

## Dependencies

- Flutter SDK 3.35.7
- `fl_chart` for pie and bar charts visualization
- `google_fonts` for custom typography styles
- `shared_preferences` for local persistence of login state
- No paid components or complex backend dependencies are used.

## Project Structure

- `lib/main.dart` - Main entry point with UI and logic
- `assets/portfolio.json` - Mock investment data file
- `pubspec.yaml` - Project configuration and dependencies

## Usage

1. Launch the app and enter your username to login.
2. View your portfolio summary on the main dashboard.
3. Explore individual holdings with details of units, cost, current value, and gains.
4. Use the toggle switch to view returns as percentage or absolute values.
5. Sort holdings using the dropdown to organize by value, gain, or name.
6. Interact with the pie chart to see asset allocation details and percentages.
7. Toggle between light and dark themes for different visual preferences.

## Notes

- The app is designed for demonstration with mock data only and does not connect to any live financial APIs.
- Sorting and data updates are handled on the client side.
- The UI is responsive and suitable for both mobile and web platforms.

## Contribution

Feel free to fork and submit pull requests for improvements or bug fixes. For major changes, open an issue first to discuss what you would like to change.

## License

This project is licensed under the MIT License.

---

Made with Flutter 3.35.7 | FL Chart | Google Fonts | Shared Preferences
