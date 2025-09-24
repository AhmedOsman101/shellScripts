#include <format>
#include <cmath>
#include <iostream>
#include <vector>

using namespace std;

int main(int argc, char* argv[]) {
  double seconds = 0;

  vector<string> out;
  string output = "";
  string time = "";
  bool isShort = false;

  // Constants
  const int ONE_DAY = 86400;
  const int ONE_HOUR = 3600;
  const int ONE_MINUTE = 60;

  if (1 < argc) seconds = atof(argv[1]);
  else {
    printf("Time is required\n");
    return 1;
  }


  if (2 < argc) {
    if (string(argv[2]) == "-s" || string(argv[2]) == "--short") isShort = true;
  }

  int days = seconds / ONE_DAY;
  seconds = fmod(seconds, ONE_DAY);

  int hours = seconds / ONE_HOUR;
  seconds = fmod(seconds, ONE_HOUR);

  int minutes = seconds / ONE_MINUTE;
  seconds = fmod(seconds, ONE_MINUTE);

  if (0 < days) {
    output = to_string(days);

    if (isShort) {
      output += "d";
    } else {
      output += days > 1 ? " days" : " day";
    }

    out.push_back(output);
  }

  if (0 < hours) {
    output = to_string(hours);

    if (isShort) {
      output += "h";
    } else {
      output += hours > 1 ? " hours" : " hour";
    }

    out.push_back(output);
  }

  if (0 < minutes) {
    output = to_string(minutes);

    if (isShort) {
      output += "m";
    } else {
      output += minutes > 1 ? " minutes" : " minute";
    }

    out.push_back(output);
  }

  if (0 < seconds) {
    if (1 <= seconds) {
      output = std::format("{:.2f}", seconds);

      if (isShort) output += "s";
      else {
        output += seconds > 1 ? " seconds" : " second";
      }

    } else {
      double ms = seconds * 1000;
      output = std::format("{:.2f}", ms);

      if (isShort) output += "ms";
      else {
        output += seconds > 1 ? " milliseconds" : " millisecond";
      }

    }

    out.push_back(output);
  }

  int len = out.size() - 1;

  for (int i = 0; i <= len; i++) {
    time += out[i];

    if (i < len && isShort) time += " ";
    else if (i == len - 1) time += " and ";
    else if (i <= len - 2) time += ", ";
  }

  cout << time << endl;
  return 0;
}
