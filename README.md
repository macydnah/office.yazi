<div align="center">

# office.yazi
### A plugin to preview office documents in <a href="https://github.com/sxyazi/yazi">Yazi <img src="https://github.com/sxyazi/yazi/blob/main/assets/logo.png?raw=true" alt="a duck" width="24px" height="24px"></a>

<img src="https://github.com/macydnah/office.yazi/blob/assets/preview_test.gif" alt="preview test" width="88%">

##

</div>

## Installation
> [!TIP]
> Installing this plugin with `ya` will conveniently clone the plugin from GitHub,
> copy it to your plugins directory, and update the `package.toml` to lock its version [^1].
> 
> To install it with `ya` run:
> ```sh
> ya pkg add macydnah/office
> ```

> Or if you prefer a manual approach:
> ```sh
> ## For linux and MacOS
> git clone https://github.com/macydnah/office.yazi.git ~/.config/yazi/plugins/office.yazi
> 
> ## For Windows
> git clone https://github.com/macydnah/office.yazi.git %AppData%\yazi\config\plugins\office.yazi
> ```

## Usage
In your `yazi.toml` add rules to preloaders[^2] and previewers[^3] to run `office` plugin with office documents.

> [!NOTE]
> Your config may be different depending if you're *appending*, *prepending* or *overriding* default rules.
> If unsure, take a look at [Configuration](https://yazi-rs.github.io/docs/configuration/overview)[^4]
> and [Configuration mixing](https://yazi-rs.github.io/docs/configuration/overview#mixing)[^5]

For a general usecase, you may use the following rules
```toml
[plugin]

prepend_preloaders = [
    # Office Documents
    { mime = "application/openxmlformats-officedocument.*", run = "office" },
    { mime = "application/oasis.opendocument.*", run = "office" },
    { mime = "application/ms-*", run = "office" },
    { mime = "application/msword", run = "office" },
    { name = "*.docx", run = "office" },
]

prepend_previewers = [
    # Office Documents
    { mime = "application/openxmlformats-officedocument.*", run = "office" },
    { mime = "application/oasis.opendocument.*", run = "office" },
    { mime = "application/ms-*", run = "office" },
    { mime = "application/msword", run = "office" },
    { name = "*.docx", run = "office" },
]
```

## Dependencies
> [!IMPORTANT]
> Make sure that these commands are installed in your system and can be found in `PATH`:
>
> - `libreoffice`
> - `pdftoppm`

## License
office.yazi is licensed under the terms of the [MIT License](LICENSE)

[^1]: [The official package manager for Yazi](https://yazi-rs.github.io/docs/cli)
[^2]: [Preloaders rules](https://yazi-rs.github.io/docs/configuration/yazi#plugin.preloaders)
[^3]: [Previewers rules](https://yazi-rs.github.io/docs/configuration/yazi#plugin.previewers)
[^4]: [Configuration](https://yazi-rs.github.io/docs/configuration/overview)
[^5]: [Configuration mixing](https://yazi-rs.github.io/docs/configuration/overview#mixing)
