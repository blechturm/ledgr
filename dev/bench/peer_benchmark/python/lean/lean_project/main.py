from AlgorithmImports import *

import csv
import json
import os
from datetime import datetime, timedelta


def load_peer_config():
    path = os.path.join(os.path.dirname(__file__), "ledgr_peer_config.json")
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


class LedgrPeerBar(PythonData):
    def GetSource(self, config, date, isLiveMode):
        path = load_peer_config()["bars_csv"]
        return SubscriptionDataSource(path, SubscriptionTransportMedium.LocalFile, FileFormat.Csv)

    def Reader(self, config, line, date, isLiveMode):
        if not line or line.startswith('"ts_utc"') or line.startswith("ts_utc"):
            return None
        row = next(csv.reader([line]))
        if len(row) < 7 or row[1] != config.Symbol.Value:
            return None
        bar = LedgrPeerBar()
        bar.Symbol = config.Symbol
        bar.Time = datetime.strptime(row[0], "%Y-%m-%d")
        bar.EndTime = bar.Time + timedelta(days=1)
        bar.Value = float(row[5])
        bar["open"] = float(row[2])
        bar["high"] = float(row[3])
        bar["low"] = float(row[4])
        bar["close"] = float(row[5])
        bar["volume"] = float(row[6])
        return bar


class LedgrPeerLeanAlgorithm(QCAlgorithm):
    def Initialize(self):
        cfg = load_peer_config()
        start = datetime.strptime(cfg["start_date"], "%Y-%m-%d")
        end = datetime.strptime(cfg["end_date"], "%Y-%m-%d")
        self.SetStartDate(start.year, start.month, start.day)
        self.SetEndDate(end.year, end.month, end.day)
        self.SetCash(10000000)
        self.fast = int(cfg["fast"])
        self.slow = int(cfg["slow"])
        self.symbols = []
        self.indicators = {}
        self.prev_above = {}

        for ticker in cfg["symbols"]:
            symbol = self.AddData(LedgrPeerBar, ticker, Resolution.Daily).Symbol
            self.symbols.append(symbol)
            self.indicators[symbol] = (
                self.SMA(symbol, self.fast, Resolution.Daily),
                self.SMA(symbol, self.slow, Resolution.Daily),
            )
            self.prev_above[symbol] = False

    def OnData(self, data):
        for symbol in self.symbols:
            if not data.ContainsKey(symbol):
                continue
            fast, slow = self.indicators[symbol]
            if not fast.IsReady or not slow.IsReady:
                self.prev_above[symbol] = False
                continue
            above = fast.Current.Value > slow.Current.Value
            was_above = self.prev_above.get(symbol, False)
            invested = self.Portfolio[symbol].Invested
            if above and not was_above and not invested:
                self.MarketOrder(symbol, 1)
            elif (not above) and was_above and invested:
                self.Liquidate(symbol)
            self.prev_above[symbol] = above
