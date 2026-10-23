"""Independent answer checks and artifact rejection tests (stdlib only)."""

import copy
import importlib.util
import itertools
import json
import math
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("practice_content", ROOT / "content.py")
CONTENT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CONTENT)


class PracticeContentTests(unittest.TestCase):
    def setUp(self):
        self.catalog = CONTENT.build_catalog()
        self.questions = {q["id"]: q for ch in self.catalog["chapters"] for q in ch["challenges"]}

    def number(self, identifier):
        return self.questions[identifier]["answer"]["numericValue"]

    def test_checked_in_artifact_is_current_and_deterministic(self):
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "content.json"
            CONTENT.export_catalog(destination)
            self.assertEqual(destination.read_bytes(), (ROOT / "content.json").read_bytes())
        self.assertEqual(json.loads((ROOT / "content.json").read_text(encoding="utf-8")), self.catalog)

    def test_all_chapters_teach_at_multiple_levels(self):
        CONTENT.validate_catalog(self.catalog)
        self.assertEqual(len(self.questions), 58)
        self.assertEqual([c["number"] for c in self.catalog["chapters"]], list(range(1, 8)))
        for chapter in self.catalog["chapters"]:
            self.assertGreaterEqual(len(chapter["challenges"]), 8)
            self.assertEqual({q["level"] for q in chapter["challenges"]}, {"foundation", "application", "challenge"})

    def test_every_numeric_answer_against_independent_reference_values(self):
        # Explicit expected answers prevent a changed formula and changed export
        # from agreeing silently. More structural derivations are tested below.
        expected = {
            "brainteasers-symmetry": 0.5, "brainteasers-series": 440, "brainteasers-pigeonhole": 5,
            "brainteasers-modular": 5, "calculus-limit": 6, "calculus-derivative": 8,
            "calculus-integral": 8, "calculus-partial": 12, "calculus-taylor": 1.22,
            "calculus-newton": 2.25, "calculus-lagrange": 36, "calculus-ode": 3.6787944117144233,
            "calculus-matrix": 2, "probability-combinations": 56, "probability-bayes": 3 / 7,
            "probability-binomial": 3 / 8, "probability-geometric": 4, "probability-expectation": -0.6,
            "probability-variance": 25, "probability-order": 2 / 3, "probability-conditional": 2 / 5,
            "stochastic-markov": 0.3, "stochastic-stationary": 2 / 3, "stochastic-walk": 2 / 5,
            "stochastic-dp": 8, "stochastic-brownian": 4, "stochastic-covariance": 2,
            "finance-call": 7, "finance-put": 0, "finance-parity": 9, "finance-delta": 60,
            "finance-neutral": 5 / 8, "finance-binomial": 250 / 21, "finance-straddle": 12,
            "algorithms-search": 7, "algorithms-inversions": 4, "algorithms-exponent": 5,
            "algorithms-bisection": 6, "algorithms-trapezoid": 3, "algorithms-monte-carlo": 0.2,
            "algorithms-euler": 2.4,
        }
        numeric_ids = {identifier for identifier, question in self.questions.items() if question["type"] == "numeric"}
        self.assertEqual(set(expected), numeric_ids)
        for identifier, target in expected.items():
            with self.subTest(identifier=identifier):
                self.assertAlmostEqual(self.number(identifier), target, places=11)

    def test_counting_and_conditioning_by_exhaustive_enumeration(self):
        self.assertEqual(self.number("probability-combinations"), len(list(itertools.combinations(range(8), 3))))
        tosses = list(itertools.product((0, 1), repeat=4))
        self.assertEqual(self.number("probability-binomial"), sum(sum(t) == 2 for t in tosses) / len(tosses))
        conditional = [(a, b) for a in range(1, 7) for b in range(1, 7) if a + b == 8]
        self.assertEqual(self.number("probability-conditional"), sum(6 in pair for pair in conditional) / len(conditional))
        # A mixture with 100 equally likely initial outcomes: A/red=15,
        # B/red=20. Conditioning leaves precisely those 35 red outcomes.
        red_outcomes = ["A"] * 15 + ["B"] * 20
        self.assertEqual(self.number("probability-bayes"), red_outcomes.count("A") / len(red_outcomes))

    def test_variance_using_an_independent_joint_distribution(self):
        values = [2 * x - y for x in (-2, 2) for y in (-3, 3)]
        mean = sum(values) / len(values)
        variance = sum((value - mean) ** 2 for value in values) / len(values)
        self.assertEqual(self.number("probability-variance"), variance)

    def test_stationary_flow_and_walk_boundary_equations(self):
        stationary_a = self.number("stochastic-stationary")
        self.assertAlmostEqual(stationary_a, stationary_a * 0.8 + (1 - stationary_a) * 0.4)
        h = [i / 5 for i in range(6)]
        self.assertEqual(h[0], 0)
        self.assertEqual(h[5], 1)
        for state in range(1, 5):
            self.assertAlmostEqual(h[state], (h[state - 1] + h[state + 1]) / 2)
        self.assertEqual(self.number("stochastic-walk"), h[2])

    def test_call_value_matches_a_replicating_portfolio_not_just_pricing_weight(self):
        # Solve the two terminal payoff equations using stock and a risk-free
        # cash position; this is independent of the generator's q-expectation.
        stock_units = (20 - 0) / (120 - 80)
        cash_now = (0 - stock_units * 80) / 1.05
        portfolio_now = stock_units * 100 + cash_now
        self.assertAlmostEqual(self.number("finance-binomial"), portfolio_now)
        self.assertAlmostEqual(stock_units * 120 + cash_now * 1.05, 20)
        self.assertAlmostEqual(stock_units * 80 + cash_now * 1.05, 0)

    def test_numerical_method_stopping_and_approximation_conventions(self):
        steps = int(self.number("algorithms-bisection"))
        self.assertLessEqual(64 / 2**steps, 1)
        self.assertGreater(64 / 2**(steps - 1), 1)
        # Sum actual trapezoid areas rather than use the export's formula.
        areas = [(0 + 1) * 1 / 2, (1 + 4) * 1 / 2]
        self.assertEqual(self.number("algorithms-trapezoid"), sum(areas))
        self.assertNotAlmostEqual(self.number("algorithms-trapezoid"), 8 / 3)

    def test_modular_invariant_for_each_legal_meeting(self):
        for red, green, blue in itertools.product(range(1, 6), repeat=3):
            transitions = [(red - 1, green - 1, blue + 2), (red - 1, green + 2, blue - 1), (red + 2, green - 1, blue - 1)]
            for new_red, new_green, new_blue in transitions:
                self.assertEqual((red - green) % 3, (new_red - new_green) % 3)
                self.assertEqual(red + green + blue, new_red + new_green + new_blue)

    def test_rejects_duplicate_answers_missing_hints_and_nonfinite_numbers(self):
        cases = []
        duplicate = copy.deepcopy(self.catalog)
        duplicate["chapters"][0]["challenges"][1]["id"] = duplicate["chapters"][0]["challenges"][0]["id"]
        cases.append(duplicate)
        hints = copy.deepcopy(self.catalog)
        hints["chapters"][0]["challenges"][0]["hints"] = ["Only one"]
        cases.append(hints)
        answer = copy.deepcopy(self.catalog)
        answer["chapters"][0]["challenges"][0]["answer"]["choiceId"] = "missing"
        cases.append(answer)
        for value in (math.nan, math.inf, -math.inf):
            malformed = copy.deepcopy(self.catalog)
            malformed["chapters"][1]["challenges"][2]["answer"]["numericValue"] = value
            cases.append(malformed)
        for malformed in cases:
            with self.subTest(case=cases.index(malformed)), self.assertRaises(ValueError):
                CONTENT.validate_catalog(malformed)


if __name__ == "__main__":
    unittest.main()
