import 'dart:io';

void main() {
  print('Enter your program type [client/server]: ');
  final String choice = stdin.readLineSync()!;

  if (choice == 'client') {
    print('Running as client...');
  } else if (choice == 'server') {
    print('Running as server...');
  } else {
    print('Invalid choice');
  }
}
