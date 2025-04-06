#include <iostream>
#include <vector>

using namespace std;

int main(int argc, char* argv[]) {
  int seconds = 0;

  vector<string> out;
  string output = "";
  string time = "";
  bool isShort = false;

  // Constants
  const int oneDay = 86400;
  const int oneHour = 3600;
  const int oneMinute = 60;

  if (1 < argc) seconds = atoi(argv[1]);
  else {
    printf("Time is required\n");
    return 1;
  }


  if (2 < argc) {
    if (string(argv[2]) == "-s" || string(argv[2]) == "--short") isShort = true;
  }

  int days = seconds / oneDay;
  seconds %= oneDay;

  int hours = seconds / oneHour;
  seconds %= oneHour;

  int minutes = seconds / oneMinute;
  seconds %= oneMinute; // Remaining seconds

  if (days > 0) {
    output = to_string(days);

    if (isShort) {
      output += "d";
    } else {
      output += days > 1 ? " Days" : " Day";
    }

    out.push_back(output);
  }

  if (hours > 0) {
    output = to_string(hours);

    if (isShort) {
      output += "h";
    } else {
      output += hours > 1 ? " Hours" : " Hour";
    }

    out.push_back(output);
  }

  if (minutes > 0) {
    output = to_string(minutes);

    if (isShort) {
      output += "m";
    } else {
      output += minutes > 1 ? " Minutes" : " Minute";
    }

    out.push_back(output);
  }

  if (seconds > 0) {
    output = to_string(seconds);

    if (isShort) {
      output += "s";
    } else {
      output += seconds > 1 ? " Seconds" : " Second";
    }

    out.push_back(output);
  }

  int len = out.size() - 1;

  for (int i = 0; i <= len; i++) {
    time += out[i];

    if (i == len) time += "";

    if (i < len && isShort)time += " ";
    else if (i == len - 1) time += " and ";
    else if (i <= len - 2) time += ", ";
  }

  cout << time << endl;
  return 0;
}
