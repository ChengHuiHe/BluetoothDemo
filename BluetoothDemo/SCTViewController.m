//
//  SCTViewController.m
//  BluetoothDemo
//
//  Created by Mugunth on 14/7/13.
//  Copyright (c) 2013 Steinlogic Consulting and Training Pte Ltd. All rights reserved.
//

#import "SCTViewController.h"

@import CoreBluetooth;

@interface SCTViewController () <CBCentralManagerDelegate, CBPeripheralDelegate>
@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) NSMutableArray *peripherals;
@property (nonatomic, weak) IBOutlet UILabel *statusLabel;
@property (nonatomic, weak) IBOutlet UILabel *temperatureLabel;
@end

@implementation SCTViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  self.temperatureLabel.text = @"这里是成功链接蓝牙后，显示当前温度！";
    self.temperatureLabel.numberOfLines = 0;
    self.temperatureLabel.font = [UIFont systemFontOfSize:28];
    
  self.peripherals = [NSMutableArray array];
  self.centralManager = [[CBCentralManager alloc] initWithDelegate:self
                                                             queue:nil
                                                           options:nil];
  
  // 应该是扫描外围
  // 扫描通过 nil 作为第一个参数将是缓慢而返回所有外围设备。
  // 然而,硬件还必须把外围广告包标识符。identifer
  // 由于TI传感器标签不寄,我们被迫扫描所有的外围设备和使用其他黑客找出哪一个是真正的传感器标签。

  if(self.centralManager.state == CBCentralManagerStatePoweredOff) {
    
    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Bluetooth Turned Off", @"")
                                message:NSLocalizedString(@"Turn on bluetooth and try again", @"")
                               delegate:self
                      cancelButtonTitle:NSLocalizedString(@"Dismiss", @"")
                      otherButtonTitles: nil] show];
    
  } else if(self.centralManager.state == CBCentralManagerStateUnsupported) {
    
    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Bluetooth LE not available on this device", @"")
                                message:NSLocalizedString(@"This is not a iPhone 4S+ device", @"")
                               delegate:self
                      cancelButtonTitle:NSLocalizedString(@"Dismiss", @"")
                      otherButtonTitles: nil] show];
    
  } else if(self.centralManager.state == CBCentralManagerStatePoweredOn) {
    
    [self.centralManager scanForPeripheralsWithServices:nil
                                                options:nil];
  }
}

/**
 *  1、 调用代理方法检测状态
 */
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
  
  if(central.state == CBCentralManagerStatePoweredOn) {

    [self.centralManager scanForPeripheralsWithServices:nil
                                                options:nil];
  } else if(self.centralManager.state == CBCentralManagerStatePoweredOff) {
    
    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Bluetooth Turned Off", @"")
                                message:NSLocalizedString(@"Turn on bluetooth and try again", @"")
                               delegate:self
                      cancelButtonTitle:NSLocalizedString(@"Dismiss", @"")
                      otherButtonTitles: nil] show];
    
  } else if(self.centralManager.state == CBCentralManagerStateUnsupported) {
    
    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Bluetooth LE not available on this device", @"")
                                message:NSLocalizedString(@"This is not a iPhone 4S+ device", @"")
                               delegate:self
                      cancelButtonTitle:NSLocalizedString(@"Dismiss", @"")
                      otherButtonTitles: nil] show];
    
  }
}

/**
 *  2、发现外围设备（调用）
 */
- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI {
  
  // 选择停止扫描更多的外围设备
  // [self.centralManager stopScan];
  if(![self.peripherals containsObject:peripheral]) {
    
    self.statusLabel.text = NSLocalizedString(@"Connecting to Peripheral", @"");
    peripheral.delegate = self;
    [self.peripherals addObject:peripheral];
    [self.centralManager connectPeripheral:peripheral options:nil];
  }
}

/**
 *  3、连接成功的设备（调用）
 */
-(void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
  
  self.statusLabel.text = NSLocalizedString(@"正在查找 services…", @"");
  [peripheral discoverServices:nil];
}


/**
 *  4、查找到可用服务
 */
-(void) peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
  
  self.statusLabel.text = NSLocalizedString(@"正在查找 characteristics…", @"");
  
  __block BOOL found = NO;
  [peripheral.services enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
    CBService *service = obj;
    
      // 红外线 服务的UUID 是F000AA00...(外围设备有好多服务，这里是只是温度的，所以只关心温度UUID)，得到服务后－－就可以发现“服务”的“特征”了！
    if([service.UUID isEqual:[CBUUID UUIDWithString:@"1000"]]) {
      [peripheral discoverCharacteristics:nil forService:service];
      found = YES;
    }
  }];
  
  if(!found)
    self.statusLabel.text = NSLocalizedString(@"This is not a Sensor Tag", @"");
}

/**
 *  5、返回已经发现的“特性”或“特征”的委托方法（已经查找到可用特征了）
 *
 *  @param peripheral 一个“服务”有多个特征
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
  
  self.statusLabel.text = NSLocalizedString(@"Reading temperature…", @"");

  [service.characteristics enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
    
      /**
       *  房间里的温度服务只有两个 “特征”，一个是“打开／关闭”服务特性，UUID是F000AA02。。。。
       */
    CBCharacteristic *ch = obj;
    if([ch.UUID isEqual:[CBUUID UUIDWithString:@"1001"]]) {
      uint8_t data = 0x01;
      [peripheral writeValue:[NSData dataWithBytes:&data length:1]
           forCharacteristic:ch
                        type:CBCharacteristicWriteWithResponse];
    }
    
      /**
       *  房间里的温度服务只有两个 “特征”，一个是“打开／关闭”服务特性，UUID是F000AA02。。。。，另一个是获取传感器读数特征，UIID是F000AA01。。。
       */
    if([ch.UUID isEqual:[CBUUID UUIDWithString:@"1003"]]) {

      [peripheral setNotifyValue:YES forCharacteristic:ch];
    }
  }];
}


/**
 *  温度的数值
 */
-(float) temperatureFromData:(NSData *)data {
  
  char scratchVal[data.length];
  int16_t ambTemp;
  [data getBytes:&scratchVal length:data.length]; // 转化成
  ambTemp = ((scratchVal[2] & 0xff)| ((scratchVal[3] << 8) & 0xff00));
  
  return (float)((float)ambTemp / (float)128);
}

/**
 *  7、执行更新特征值后的代理方法(第二个参数包含特征)
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
  
  float temp = [self temperatureFromData:characteristic.value]; // 你可以用value属性读取他的值
  self.statusLabel.text = NSLocalizedString(@"Room temperature", @"");
  self.temperatureLabel.text = [NSString stringWithFormat:@"%.1f°C", temp];
}



@end
