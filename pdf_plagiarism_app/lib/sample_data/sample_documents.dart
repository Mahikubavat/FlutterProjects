import '../models/assignment_document.dart';

/// Three sample "lab report" texts so the app is useful the moment you
/// run it, without hunting for real PDFs. Student A and Student B share
/// a heavily copy-pasted results/conclusion section (a realistic
/// plagiarism case); Student C is original and on a different topic.
class SampleDocuments {
  static List<AssignmentDocument> get all => [
        const AssignmentDocument(
          id: 'sample-a',
          fileName: 'student_A_newtons_law.pdf',
          rawText:
              "Introduction: The purpose of this experiment is to verify Newton's "
              "second law of motion using a frictionless track and varying masses. "
              "Newton's second law states that the acceleration of an object is "
              "directly proportional to the net force acting on it and inversely "
              "proportional to its mass. In this experiment we used a low friction "
              "air track, a photogate timer, and a set of calibrated weights to "
              "measure acceleration under different applied forces. Methodology: A "
              "cart was placed on the air track and connected via a string over a "
              "pulley to a hanging mass. The photogate recorded the time intervals "
              "as the cart passed through two points. We varied the hanging mass in "
              "five trials while keeping total system mass constant by transferring "
              "mass between the cart and the hanger. Results: The measured "
              "acceleration increased linearly with the applied force, consistent "
              "with theoretical predictions. The slope of the force versus "
              "acceleration graph closely matched the total mass of the system, "
              "confirming Newton's second law within experimental error of about "
              "three percent. Conclusion: Our results support Newton's second law "
              "of motion. Minor discrepancies are attributed to friction in the "
              "pulley and air resistance.",
        ),
        const AssignmentDocument(
          id: 'sample-b',
          fileName: 'student_B_newtons_law.pdf',
          rawText:
              "Lab Report: Verifying Newton's Second Law. Objective: This lab "
              "explores how force and mass affect acceleration. We used an air "
              "track setup to minimize friction effects during data collection. "
              "Newton's second law states that the acceleration of an object is "
              "directly proportional to the net force acting on it and inversely "
              "proportional to its mass. In this experiment we used a low friction "
              "air track, a photogate timer, and a set of calibrated weights to "
              "measure acceleration under different applied forces. A cart was "
              "placed on the air track and connected via a string over a pulley to "
              "a hanging mass. The photogate recorded the time intervals as the "
              "cart passed through two points. We varied the hanging mass in five "
              "trials while keeping total system mass constant by transferring "
              "mass between the cart and the hanger. The measured acceleration "
              "increased linearly with the applied force, consistent with "
              "theoretical predictions. The slope of the force versus acceleration "
              "graph closely matched the total mass of the system, confirming "
              "Newton's second law within experimental error of about three "
              "percent. Our results support Newton's second law of motion. Minor "
              "discrepancies are attributed to friction in the pulley and air "
              "resistance.",
        ),
        const AssignmentDocument(
          id: 'sample-c',
          fileName: 'student_C_pendulum.pdf',
          rawText:
              "This experiment investigates the relationship between pendulum "
              "length and period of oscillation. A simple pendulum was constructed "
              "using a string and a small steel bob, with length varied across six "
              "trials from twenty to eighty centimeters. For each length, the time "
              "for twenty full oscillations was recorded using a stopwatch and "
              "averaged over three repeated measurements to reduce timing error. "
              "The period was calculated by dividing total time by the number of "
              "oscillations. A graph of period squared against pendulum length "
              "produced a straight line, matching the theoretical relationship "
              "derived from the small angle approximation of simple harmonic "
              "motion. The calculated value of gravitational acceleration from the "
              "slope was nine point seven five meters per second squared, within "
              "two percent of the accepted value. Sources of error include air "
              "resistance, the finite size of the bob, and human reaction time "
              "during manual timing with a stopwatch.",
        ),
      ];
}
