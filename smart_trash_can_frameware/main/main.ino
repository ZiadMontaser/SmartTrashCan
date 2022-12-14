#include <Servo.h>
#include <NewPing.h>
#include <SoftwareSerial.h>
#include <ArduinoJson.h>

#define ContactNumber  "+201060109960"
#define SimNumber      "+201552124205"
#define APN           "internet.te.eg"

DynamicJsonDocument doc(200);

// Rx 3, Tx 2
SoftwareSerial gsm(3, 2);

//Echo 11 Trigger 10
NewPing motionSensor(11, 10);
//Ech 9 Trigger 8
NewPing levelSensor(9, 8);
//Servo 7
Servo openServo;

float depth = 40;

bool isOpen = false;

void setup() {
  pinMode(13, OUTPUT);
  pinMode(8,OUTPUT);
  openServo.attach(7);
  
  // put your setup code here, to run once:
  Serial.begin(9600);
  //Begin serial communication with Arduino and SIM800L
  gsm.begin(9600);

  Serial.println("Initializing...");
  
  CheckConnection();
  SetupSMS();
  SetupGPRS(APN);
}

void loop() {
  // put your main code here, to run repeatedly:
  updateSerial();
  

  delay(1000);
//  UpdateData(SimNumber);

  if(motionSensor.ping_cm() < 20 && motionSensor.ping_cm() > 2){
    if(!isOpen){
      OpenBin();
    }
  }else{
    if(isOpen){
      CloseBin();
    }
  }
}

void updateSerial()
{
  delay(500 * 2);
  while (Serial.available()) 
  {
    gsm.write(Serial.read());//Forward what Serial received to Software Serial Port
  }
  while(gsm.available()) 
  {
     String sms = gsm.readString();

    if(sms.indexOf("+CMT:") > 0){
      Serial.print(sms);
      int index = sms.lastIndexOf('"');
      String message = sms.substring(index+3, sms.length());
      String param = message.substring(message.lastIndexOf(' ')+1, message.length()) ;
      Serial.println("Message is :" + message );
      if(sms.indexOf("Info") > 0){
          ReWriteData(SimNumber);
          String output;
          serializeJsonPretty(doc, output);
          SendMessage(output);
      }else if(sms.indexOf("Depth") > 0){
        depth = param.toFloat();
        
        SendMessage("Set depth to " + String(depth));
      }else if(sms.indexOf("Open") > 0){
        OpenBin();
      }else if(sms.indexOf("Close") > 0){
        CloseBin();
      }
    }else{
      Serial.print("{" + sms + "}");//Forward what Software Serial received to Serial Port
    }
  }
}
void OpenBin(){
  openServo.write(110);
  isOpen = true;
}

void CloseBin(){
  openServo.write(10);
  isOpen = false;

  delay(1000 * 2);
  
  UpdateData(SimNumber);

  int levelPercent = (depth - motionSensor.ping_cm()) / depth;
  if(levelPercent > 80){
    SendMessage("The trash can is about to be full -- " + String(levelPercent));  
  }
}

void SetDepth(float depth){
  
}

void ReWriteData(String Simnumber){
  doc["depth"]= depth;
  doc["isOpened"]= isOpen;
  doc["level_distance"]= levelSensor.ping_cm();
  doc["motion_distance"]= motionSensor.ping_cm();
}

void CheckConnection(){
   gsm.println("AT"); //Once the handshake test is successful, it will back to OK
  updateSerial();
  gsm.println("AT+CSQ"); //Signal quality test, value range is 0-31 , 31 is the best
  updateSerial();
  gsm.println("AT+CCID"); //Read SIM information to confirm whether the SIM is plugged
  updateSerial();
  gsm.println("AT+CREG?"); //Check whether it has registered in the network
  updateSerial();
}

void SetupGPRS(String apn){
  gsm.println("AT+SAPBR=3,1,\"Contype\",\"GPRS\""); //Set connection type to GPRS
  updateSerial();
  
  gsm.println("AT+SAPBR=3,1,\"APN\",\"" + apn + "\""); //Set APN
  updateSerial();
  
  gsm.println("AT+SAPBR=1,1");
  updateSerial();

  gsm.println("AT+SAPBR=2,1");
  updateSerial();
}

void UpdateData(String Simnumber){
//  gsm.println("AT+HTTPTERM");
//    delay(1000*5);
  gsm.println("AT+HTTPINIT");
  updateSerial();

  gsm.println("AT+HTTPPARA=\"CID\",1");
  updateSerial();

  gsm.println("AT+HTTPPARA=\"URL\",\"auto-connect-8.firebaseio.com/cans/" + Simnumber + "/state.json\""); //Server address
  updateSerial();
  
  gsm.println("AT+HTTPSSL=1");
  updateSerial();
 
  gsm.println("AT+HTTPPARA=\"CONTENT\",\"application/json\""); 
  updateSerial();
 
  
//DATA
  ReWriteData(Simnumber);

  gsm.println("AT+HTTPDATA=" + String(measureJsonPretty(doc)) + ",100000");
  updateSerial();
  
  serializeJsonPretty(doc, gsm);
  serializeJsonPretty(doc, Serial);
  updateSerial();
//////
  delay(1000);
  gsm.println("AT+HTTPACTION=1");
  updateSerial();
 
  gsm.println("AT+HTTPREAD");
  updateSerial();
 
  gsm.println("AT+HTTPTERM");
}

void SetupSMS(){
  gsm.println("AT+CMGF=1"); // Configuring TEXT mode
  updateSerial();
  gsm.println("AT+CNMI=1,2,0,0,0");
  updateSerial();
}

void SendMessage(String content){
  Serial.print("Sent Message : " + content);
  gsm.println("AT+CMGF=1"); // Configuring TEXT mode
  updateSerial();
  gsm.println("AT+CMGS=\""+String(ContactNumber)+"\"");//change ZZ with country code and xxxxxxxxxxx with phone number to sms
  updateSerial();
  gsm.print(content); //text content
  updateSerial();
  gsm.write(26);
}
