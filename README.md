# RuuviTag reader

Linux shell script to read ruuvi beacons. The script supports
[Ruuvi V3 specification](https://github.com/ruuvi/ruuvi-sensor-protocols/blob/master/dataformat_03.md).

## Usage

Call the script with ruuvitag MAC address and optionally specify a timeout.
The MAC address can be found for example with `bluetoothctl`. Beacons are
listened for 10 seconds by default.

```console
foo@bar:~$ ./ruuvi_v3_reader.sh <--mac mac_address> [--timeout timeout_seconds]
```

Beacons are listened for timeout duration and the last received beacon is
used for calculation.

The scipt will return a JSON formatted line with the values like:

```json
{
  "observation_time":"2021-06-25T17:07:29+00:00",
  "temperature":26.30,
  "pressure":1027.66,
  "humidity":20.5,
  "accl_x":-1.000,
  "accl_y":-1.726,
  "accl_z":0.714,
  "battery_voltage":2.899
}
```

Where the values are:

* observation_time - UTC time
* temperature - in celsius
* pressure - hPa
* humidity - Relative humidity (RH)
* accl - G
* battery_voltage - V
