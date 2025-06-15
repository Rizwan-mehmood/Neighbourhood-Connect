class WelcomeData {
  final String title;
  final String description;

  WelcomeData({
    required this.title,
    required this.description,
  });
}

final List<WelcomeData> welcomeScreens = [
  WelcomeData(
    title: 'Welcome to Neighborhood Connect',
    description: 'Stay connected with neighbors and local communities effortlessly.',
  ),
  WelcomeData(
    title: 'Engage and Share',
    description: 'Post updates, events, and important news with your neighbors.',
  ),
  WelcomeData(
    title: 'Stay Notified',
    description: 'Receive alerts and notifications about nearby activities.',
  ),
];
