
module Base.Renderable.BusyMessage (busyMessage) where


import Base.Types
import Base.Prose
import Base.Font ()

import Base.Renderable.WholeScreenPixmap
import Base.Renderable.Layered
import Base.Renderable.Centered


busyMessage :: Prose -> RenderableInstance
busyMessage text =
    RenderableInstance (
        MenuBackground |:>
        (centered $ text)
      )
