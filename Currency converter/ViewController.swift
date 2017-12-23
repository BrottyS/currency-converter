import UIKit

class ViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {

    @IBOutlet weak var pickerFrom: UIPickerView!
    @IBOutlet weak var pickerTo: UIPickerView!
    
    @IBOutlet weak var oneLabel: UILabel!
    @IBOutlet weak var equalLabel: UILabel!
    @IBOutlet weak var rateLabel: UILabel!
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var errorLabel: UILabel!
    
    var currencies = ["EUR", "RUB", "USD"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupView()
        
        self.pickerFrom.dataSource = self
        self.pickerTo.dataSource = self
        
        self.pickerFrom.delegate = self
        self.pickerTo.delegate = self
        
        self.activityIndicator.hidesWhenStopped = true
        
        //self.requestCurrentCurrencyRate()
        
        self.retrieveCurrencyBases() { [weak self] (currencyBases) in
            DispatchQueue.main.async(execute: {
                if let strongSelf = self {
                    if currencyBases.count > 0 {
                        strongSelf.currencies = currencyBases
                        // because EUR is base currency on api.fixer.io
                        if !currencyBases.contains("EUR") {
                            strongSelf.currencies.append("EUR")
                        }
                        strongSelf.currencies = strongSelf.currencies.sorted()
                        strongSelf.pickerFrom.reloadAllComponents()
                        strongSelf.pickerTo.reloadAllComponents()
                        strongSelf.requestCurrentCurrencyRate()
                    } else {
                        strongSelf.currencies = ["EUR", "RUB", "USD"]
                    }
                }
            })
        }
    }
    
    func setupView() {
        self.navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.white]
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        
        self.view.backgroundColor = .cc_veryDarkGray
        
        self.pickerFrom.backgroundColor = .cc_darkGray
        self.pickerTo.backgroundColor = .cc_darkGray
        
        self.pickerFrom.layer.cornerRadius = 4.0
        self.pickerTo.layer.cornerRadius = 4.0
        
        self.oneLabel.textColor = .cc_blue
        self.equalLabel.textColor = .cc_blue
        self.rateLabel.textColor = .cc_blue
        
        self.activityIndicator.color = .cc_blue
        
        self.errorLabel.textColor = .cc_red
        
        self.rateLabel.text = "?"
        self.errorLabel.text = ""
    }
    
    // MARK: - UIPickerViewDataSource
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if pickerView === pickerTo {
            return self.currenciesExceptBase().count
        }
        
        return currencies.count
    }
    
    // MARK: - UIPickerViewDelegate
    
    /*
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView === pickerTo {
            return self.currenciesExceptBase()[row]
        }
        
        return currencies[row]
    }*/
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        let title: String
        
        if pickerView === pickerTo {
            title = self.currenciesExceptBase()[row]
        } else {
            title = currencies[row]
        }
        
        return NSAttributedString(string: title, attributes: [NSForegroundColorAttributeName: UIColor.white])
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView === pickerFrom {
            self.pickerTo.reloadAllComponents()
        }
        
        self.requestCurrentCurrencyRate()
    }
    
    // MARK: - Networking
    
    func requestCurrencyRates(baseCurrency: String, parseHandler: @escaping (Data?, Error?) -> Void) {
        let url = URL(string: "https://api.fixer.io/latest?base=" + baseCurrency)!
        
        let dataTask = URLSession.shared.dataTask(with: url) { (dataReceived, response, error) in
            parseHandler(dataReceived, error)
        }
        
        dataTask.resume()
    }
    
    func requestCurrencyBases(parseHandler: @escaping (Data?, Error?) -> Void) {
        let url = URL(string: "https://api.fixer.io/latest")!
        
        let dataTask = URLSession.shared.dataTask(with: url) { (dataReceived, response, error) in
            parseHandler(dataReceived, error)
        }
        
        dataTask.resume()
    }
    
    // MARK: - Parsing
    
    /*
    func parseCurrencyRatesResponse(data: Data?, toCurrency: String) -> String {
        var value: String = ""
        
        do {
            let json = try JSONSerialization.jsonObject(with: data!, options: []) as? Dictionary<String, Any>
            
            if let parsedJson = json {
                print("\(parsedJson)")
                if let rates = parsedJson["rates"] as? Dictionary<String, Double> {
                    if let rate = rates[toCurrency] {
                        value = "\(rate)"
                    } else {
                        value = "No rate for currency \"\(toCurrency)\" found"
                    }
                } else {
                    value = "No \"rates\" field found"
                }
            } else {
                value = "No JSON value parsed"
            }
        } catch {
            value = error.localizedDescription
        }
        
        return value
    }*/
    
    enum ParseError: Error {
        case failed(String)
    }
    
    func parseCurrencyRatesResponse(data: Data?, toCurrency: String) throws -> String {
        var value: String = "?"
        
        let json = try JSONSerialization.jsonObject(with: data!, options: []) as? Dictionary<String, Any>
        
        if let parsedJson = json {
            print("\(parsedJson)")
            if let rates = parsedJson["rates"] as? Dictionary<String, Double> {
                if let rate = rates[toCurrency] {
                    value = "\(rate)"
                } else {
                    throw ParseError.failed("No rate for currency \"\(toCurrency)\" found")
                }
            } else {
                throw ParseError.failed("No \"rates\" field found")
            }
        } else {
            throw ParseError.failed("No JSON value parsed")
        }
        
        return value
    }
    
    func parseCurrencyBasesResponse(data: Data?) throws -> [String] {
        var bases = [String]()
        
        let json = try JSONSerialization.jsonObject(with: data!, options: []) as? Dictionary<String, Any>
        
        if let parsedJson = json {
            print("\(parsedJson)")
            if let rates = parsedJson["rates"] as? Dictionary<String, Any> {
                for base in rates {
                    bases.append(base.key)
                }
            } else {
                throw ParseError.failed("No \"rates\" field found")
            }
        } else {
            throw ParseError.failed("No JSON value parsed")
        }
        
        return bases
    }
    
    // MARK: - Business logic
    
    func retrieveCurrencyRate(baseCurrency: String, toCurrency: String, completion: @escaping (String) -> Void) {
        self.requestCurrencyRates(baseCurrency: baseCurrency) { [weak self] (data, error) in
            var string = "?"
            
            if let currentError = error {
                DispatchQueue.main.async(execute: {
                    if let strongSelf = self {
                        strongSelf.showError(currentError.localizedDescription)
                    }
                })
            } else {
                if let strongSelf = self {
                    do {
                        string = try strongSelf.parseCurrencyRatesResponse(data: data, toCurrency: toCurrency)
                    } catch ParseError.failed(let reason) {
                        DispatchQueue.main.async(execute: {
                            strongSelf.showError(reason)
                        })
                    } catch {
                        DispatchQueue.main.async(execute: {
                            strongSelf.showError(error.localizedDescription)
                        })
                    }
                }
            }
            
            completion(string)
        }
    }
    
    func requestCurrentCurrencyRate() {
        self.errorLabel.text = ""
        self.showRateLoading(true)
        let baseCurrencyIndex = self.pickerFrom.selectedRow(inComponent: 0)
        let toCurrencyIndex = self.pickerTo.selectedRow(inComponent: 0)
        
        let baseCurrency = self.currencies[baseCurrencyIndex]
        let toCurrency = self.currenciesExceptBase()[toCurrencyIndex]
        
        self.retrieveCurrencyRate(baseCurrency: baseCurrency, toCurrency: toCurrency) { [weak self] (value) in
            DispatchQueue.main.async(execute: {
                if let strongSelf = self {
                    strongSelf.rateLabel.text = value
                    strongSelf.showRateLoading(false)
                }
            })
        }
    }
    
    func retrieveCurrencyBases(completion: @escaping ([String]) -> Void) {
        self.requestCurrencyBases() { [weak self] (data, error) in
            var currencyBases = [String]()
            
            if let currentError = error {
                DispatchQueue.main.async(execute: {
                    if let strongSelf = self {
                        strongSelf.showError(currentError.localizedDescription)
                    }
                })
            } else {
                if let strongSelf = self {
                    do {
                        currencyBases = try strongSelf.parseCurrencyBasesResponse(data: data)
                    } catch ParseError.failed(let reason) {
                        DispatchQueue.main.async(execute: {
                            strongSelf.showError(reason)
                        })
                    } catch {
                        DispatchQueue.main.async(execute: {
                            strongSelf.showError(error.localizedDescription)
                        })
                    }
                }
            }
            
            completion(currencyBases)
        }
    }
    
    // MARK: - Utils
    
    func currenciesExceptBase() -> [String] {
        var currenciesExceptBase = currencies
        currenciesExceptBase.remove(at: pickerFrom.selectedRow(inComponent: 0))
        
        return currenciesExceptBase
    }
    
    func showRateLoading(_ loading: Bool) {
        if loading {
            self.rateLabel.isHidden = true
            self.activityIndicator.startAnimating()
        } else {
            self.rateLabel.isHidden = false
            self.activityIndicator.stopAnimating()
        }
    }
    
    func showError(_ error: String) {
        self.errorLabel.text = error
    }

}

